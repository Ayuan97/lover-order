package apple

import (
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v4"
	"lover-order-backend/internal/config"
)

// IdentityClaims Apple identity_token 中的声明字段
type IdentityClaims struct {
	Email         string `json:"email"`
	EmailVerified any    `json:"email_verified"`
	IsPrivateRel  any    `json:"is_private_email"`
	jwt.RegisteredClaims
}

// jwk 描述 JWKS 中的单个 key
type jwk struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type jwks struct {
	Keys []jwk `json:"keys"`
}

type keyCache struct {
	mu        sync.RWMutex
	keys      map[string]*rsa.PublicKey
	expiresAt time.Time
}

var cache = &keyCache{keys: map[string]*rsa.PublicKey{}}

// Verify 验证 Apple identity_token 并返回声明
func Verify(idToken string) (*IdentityClaims, error) {
	cfg := config.AppConfig
	if cfg == nil {
		return nil, errors.New("配置未初始化")
	}

	token, err := jwt.ParseWithClaims(idToken, &IdentityClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodRSA); !ok {
			return nil, fmt.Errorf("签名算法不是 RSA：%v", t.Header["alg"])
		}
		kid, _ := t.Header["kid"].(string)
		if kid == "" {
			return nil, errors.New("identity_token 缺少 kid")
		}
		return loadKey(kid, cfg.Apple.JWKSURL)
	})
	if err != nil {
		return nil, fmt.Errorf("identity_token 校验失败：%w", err)
	}

	claims, ok := token.Claims.(*IdentityClaims)
	if !ok || !token.Valid {
		return nil, errors.New("identity_token 无效")
	}

	if cfg.Apple.Issuer != "" {
		if !claims.VerifyIssuer(cfg.Apple.Issuer, true) {
			return nil, errors.New("identity_token issuer 不匹配")
		}
	}
	if cfg.Apple.ClientID != "" {
		if !claims.VerifyAudience(cfg.Apple.ClientID, true) {
			return nil, errors.New("identity_token audience 不匹配 client_id")
		}
	}

	if claims.Subject == "" {
		return nil, errors.New("identity_token 缺少 sub")
	}
	return claims, nil
}

func loadKey(kid, jwksURL string) (*rsa.PublicKey, error) {
	cache.mu.RLock()
	key, ok := cache.keys[kid]
	fresh := time.Now().Before(cache.expiresAt)
	cache.mu.RUnlock()
	if ok && fresh {
		return key, nil
	}

	if err := refreshKeys(jwksURL); err != nil {
		return nil, err
	}

	cache.mu.RLock()
	defer cache.mu.RUnlock()
	if k, ok := cache.keys[kid]; ok {
		return k, nil
	}
	return nil, fmt.Errorf("Apple JWKS 中找不到 kid %s", kid)
}

func refreshKeys(jwksURL string) error {
	resp, err := http.Get(jwksURL)
	if err != nil {
		return fmt.Errorf("拉取 Apple JWKS 失败：%w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("读取 JWKS body 失败：%w", err)
	}

	var set jwks
	if err := json.Unmarshal(body, &set); err != nil {
		return fmt.Errorf("解析 JWKS 失败：%w", err)
	}

	parsed := map[string]*rsa.PublicKey{}
	for _, k := range set.Keys {
		if k.Kty != "RSA" {
			continue
		}
		pub, err := toRSAKey(k.N, k.E)
		if err != nil {
			return err
		}
		parsed[k.Kid] = pub
	}

	cache.mu.Lock()
	defer cache.mu.Unlock()
	cache.keys = parsed
	cache.expiresAt = time.Now().Add(time.Hour)
	return nil
}

func toRSAKey(nB64, eB64 string) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(nB64)
	if err != nil {
		return nil, fmt.Errorf("解码 JWK n 失败：%w", err)
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(eB64)
	if err != nil {
		return nil, fmt.Errorf("解码 JWK e 失败：%w", err)
	}
	e := 0
	for _, b := range eBytes {
		e = e<<8 | int(b)
	}
	return &rsa.PublicKey{
		N: new(big.Int).SetBytes(nBytes),
		E: e,
	}, nil
}
