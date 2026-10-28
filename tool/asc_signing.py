#!/usr/bin/env python3
"""Signature App Store durable via l'API App Store Connect.

  setup  réutilise (ou crée la première fois) une clé privée, un certificat
         « Apple Distribution » et un profil App Store pour le bundle ; écrit
         le .p12 et le profil, et ajoute leurs références à $GITHUB_ENV.

Le certificat n'est JAMAIS révoqué : Apple revérifie la signature lors de
l'examen, et un certificat révoqué entre l'envoi et l'examen fait rejeter le
build (ITMS-90035 Invalid Signature).

La clé privée est conservée chiffrée (AES-256-GCM, clé dérivée du secret
ASC_KEY_P8) dans le fichier KEY_STORE ; si une nouvelle clé est créée, elle
est écrite chiffrée dans NEW_KEY_STORE pour que le workflow la sauvegarde.

Variables : KEY_ID, ISSUER_ID, KEY_PATH (fichier .p8), BUNDLE_ID, OUT_DIR,
P12_PASSWORD, KEY_STORE (facultatif), NEW_KEY_STORE.
Dépendances : pyjwt, cryptography.
"""
import base64
import datetime
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

API = 'https://api.appstoreconnect.apple.com/v1'


def token() -> str:
    key = open(os.environ['KEY_PATH'], encoding='utf-8').read()
    now = int(time.time())
    return jwt.encode(
        {'iss': os.environ['ISSUER_ID'], 'iat': now, 'exp': now + 900,
         'aud': 'appstoreconnect-v1'},
        key,
        algorithm='ES256',
        headers={'kid': os.environ['KEY_ID'], 'typ': 'JWT'},
    )


def call(method: str, path: str, body=None):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': f'Bearer {token()}',
                 'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors='replace')
        sys.exit(f'::error::App Store Connect {method} {path} : {e.code} {detail}')


def env_out(**kv):
    path = os.environ.get('GITHUB_ENV')
    for k, v in kv.items():
        print(f'{k}={v}')
        if path:
            with open(path, 'a', encoding='utf-8') as f:
                f.write(f'{k}={v}\n')


PROFILE_NAME = 'CliniFlow CI AppStore'


def _aes() -> AESGCM:
    p8 = open(os.environ['KEY_PATH'], 'rb').read().strip()
    return AESGCM(hashlib.sha256(b'cliniflow-signing:' + p8).digest())


def load_key():
    path = os.environ.get('KEY_STORE', '')
    if not path or not os.path.isfile(path) or os.path.getsize(path) == 0:
        return None
    try:
        blob = json.load(open(path, encoding='utf-8'))
        pem = _aes().decrypt(base64.b64decode(blob['nonce']),
                             base64.b64decode(blob['ct']), None)
        return serialization.load_pem_private_key(pem, None)
    except Exception as e:  # clé .p8 changée, fichier abîmé…
        print(f'::warning::Clé de signature sauvegardée illisible ({e}) ; '
              'une nouvelle sera créée.')
        return None


def save_key(key):
    pem = key.private_bytes(serialization.Encoding.PEM,
                            serialization.PrivateFormat.PKCS8,
                            serialization.NoEncryption())
    nonce = os.urandom(12)
    ct = _aes().encrypt(nonce, pem, None)
    with open(os.environ['NEW_KEY_STORE'], 'w', encoding='utf-8') as f:
        json.dump({'nonce': base64.b64encode(nonce).decode(),
                   'ct': base64.b64encode(ct).decode()}, f)
    env_out(ASC_NEW_KEY=os.environ['NEW_KEY_STORE'])


def _valid_until(iso: str, days: int) -> bool:
    exp = datetime.datetime.fromisoformat(iso.replace('Z', '+00:00'))
    limit = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=days)
    return exp > limit


def find_certificate(key):
    """Certificat Apple Distribution valide correspondant à la clé."""
    pub = key.public_key().public_numbers()
    q = urllib.parse.urlencode({'filter[certificateType]': 'DISTRIBUTION',
                                'limit': 200})
    for c in call('GET', f'/certificates?{q}')['data']:
        a = c['attributes']
        if not a.get('certificateContent') or not _valid_until(a['expirationDate'], 14):
            continue
        cert = x509.load_der_x509_certificate(base64.b64decode(a['certificateContent']))
        if cert.public_key().public_numbers() == pub:
            return c['id'], cert
    return None


def create_certificate(key):
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([
               x509.NameAttribute(NameOID.COMMON_NAME, 'CliniFlow CI'),
               x509.NameAttribute(NameOID.COUNTRY_NAME, 'FR'),
           ]))
           .sign(key, hashes.SHA256()))
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()
    c = call('POST', '/certificates', {'data': {
        'type': 'certificates',
        'attributes': {'certificateType': 'DISTRIBUTION', 'csrContent': csr_pem},
    }})['data']
    der = base64.b64decode(c['attributes']['certificateContent'])
    return c['id'], x509.load_der_x509_certificate(der)


def find_or_create_profile(bundle_rid, cert_id):
    q = urllib.parse.urlencode({'filter[name]': PROFILE_NAME})
    for p in call('GET', f'/profiles?{q}')['data']:
        a = p['attributes']
        certs = [c['id'] for c in call('GET', f'/profiles/{p["id"]}/certificates')['data']]
        if (a.get('profileState') == 'ACTIVE' and cert_id in certs
                and _valid_until(a['expirationDate'], 14)):
            print('profil existant réutilisé')
            return p
        # Profil périmé ou lié à un autre certificat : on le remplace
        # (supprimer un profil n'invalide pas les builds déjà envoyés).
        call('DELETE', f'/profiles/{p["id"]}')
    print('nouveau profil créé')
    return call('POST', '/profiles', {'data': {
        'type': 'profiles',
        'attributes': {'name': PROFILE_NAME, 'profileType': 'IOS_APP_STORE'},
        'relationships': {
            'bundleId': {'data': {'type': 'bundleIds', 'id': bundle_rid}},
            'certificates': {'data': [{'type': 'certificates', 'id': cert_id}]},
        },
    }})['data']


def setup():
    bundle = os.environ['BUNDLE_ID']
    out = os.environ['OUT_DIR']
    password = os.environ['P12_PASSWORD'].encode()
    os.makedirs(out, exist_ok=True)

    # 1. Identifiant du bundle enregistré.
    q = urllib.parse.urlencode({'filter[identifier]': bundle})
    ids = [b for b in call('GET', f'/bundleIds?{q}')['data']
           if b['attributes']['identifier'] == bundle]
    if not ids:
        sys.exit(f'::error::Identifiant {bundle} introuvable : enregistrez-le '
                 'dans developer.apple.com › Identifiers.')
    bundle_rid = ids[0]['id']

    # 2. Clé privée durable.
    key = load_key()
    if key is None:
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        save_key(key)
        print('nouvelle clé de signature créée')

    # 3. Certificat Apple Distribution : réutilisé s'il existe, sinon créé.
    found = find_certificate(key)
    if found:
        print('certificat existant réutilisé')
        cert_id, certificate = found
    else:
        print('nouveau certificat créé')
        cert_id, certificate = create_certificate(key)

    # 4. Profil App Store lié au certificat.
    prof = find_or_create_profile(bundle_rid, cert_id)
    env_out(ASC_PROFILE_NAME=PROFILE_NAME)
    profile_path = os.path.join(out, 'appstore.mobileprovision')
    with open(profile_path, 'wb') as f:
        f.write(base64.b64decode(prof['attributes']['profileContent']))
    env_out(ASC_PROFILE_UUID=prof['attributes']['uuid'],
            ASC_PROFILE_PATH=profile_path)

    # 5. .p12 compatible avec le trousseau macOS.
    enc = (serialization.PrivateFormat.PKCS12.encryption_builder()
           .kdf_rounds(50000)
           .key_cert_algorithm(pkcs12.PBES.PBESv1SHA1And3KeyTripleDESCBC)
           .hmac_hash(hashes.SHA1())
           .build(password))
    p12 = pkcs12.serialize_key_and_certificates(
        b'CliniFlow CI', key, certificate, None, enc)
    p12_path = os.path.join(out, 'dist.p12')
    with open(p12_path, 'wb') as f:
        f.write(p12)
    env_out(ASC_P12_PATH=p12_path)


if __name__ == '__main__':
    {'setup': setup}[sys.argv[1]]()
