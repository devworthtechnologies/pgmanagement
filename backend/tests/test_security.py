import uuid
import pytest
import hashlib
from datetime import datetime, timedelta, timezone
from jose import jwt

from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_access_token
)
from app.core.exceptions import InvalidTokenError
from app.core.config import settings


def test_password_hashing_and_verification():
    password = "supersecretpassword"
    hashed = hash_password(password)
    
    assert hashed != password
    # Correct password verifies
    assert verify_password(password, hashed) is True
    # Wrong password fails
    assert verify_password("wrongpassword", hashed) is False

def test_refresh_token_creation():
    raw_token, token_hash = create_refresh_token()
    
    assert isinstance(raw_token, str)
    assert len(raw_token) > 0
    
    expected_hash = hashlib.sha256(raw_token.encode("utf-8")).hexdigest()
    assert token_hash == expected_hash

def test_access_token_decodes_to_right_user_id():
    user_id = uuid.uuid4()
    token = create_access_token(user_id)
    
    decoded_user_id = decode_access_token(token)
    assert decoded_user_id == user_id

def test_expired_token_raises_error():
    user_id = uuid.uuid4()
    
    # Manually create an expired token
    expire = datetime.now(timezone.utc) - timedelta(minutes=10)
    to_encode = {"exp": expire, "sub": str(user_id)}
    expired_token = jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    
    with pytest.raises(InvalidTokenError, match="expired"):
        decode_access_token(expired_token)

def test_tampered_signature_token_raises_error():
    user_id = uuid.uuid4()
    token = create_access_token(user_id)

    # Tamper in the MIDDLE of the signature, never the last character. An
    # HMAC-SHA256 signature is 32 bytes = 256 bits rendered as 43 base64url
    # characters = 258 bits, so the final character carries only 4 significant
    # bits and its low 2 are padding. Swapping it therefore decodes to the very
    # same signature bytes about 6% of the time (measured: 127/2000), and the
    # "tampered" token verifies fine — which made this test pass a forged token
    # roughly one run in sixteen. Every other character is fully significant.
    header, payload, signature = token.split(".")
    mid = len(signature) // 2
    tampered_signature = signature[:mid] + ("a" if signature[mid] != "a" else "b") + signature[mid + 1:]
    tampered_token = f"{header}.{payload}.{tampered_signature}"

    # Belt and braces: if the swap above ever produced the original string the
    # test would be asserting nothing at all.
    assert tampered_token != token

    with pytest.raises(InvalidTokenError, match="Invalid token signature"):
        decode_access_token(tampered_token)

def test_missing_sub_claim_raises_error():
    # Token without the 'sub' claim
    expire = datetime.now(timezone.utc) + timedelta(minutes=10)
    to_encode = {"exp": expire}
    token_missing_sub = jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    
    with pytest.raises(InvalidTokenError, match="missing 'sub' claim"):
        decode_access_token(token_missing_sub)
