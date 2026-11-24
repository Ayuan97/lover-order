package oss

import (
	"context"
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path"
	"strings"
	"time"
)

// Config 阿里云 OSS 配置
type Config struct {
	Endpoint        string
	Bucket          string
	AccessKeyID     string
	AccessKeySecret string
	Prefix          string
	PublicBaseURL   string
}

// Client 轻量级阿里云 OSS 客户端（基于标准库 HTTP + OSS V1 HMAC-SHA1 签名）
type Client struct {
	endpoint        string
	bucket          string
	accessKeyID     string
	accessKeySecret string
	prefix          string
	publicBaseURL   string
	httpClient      *http.Client
}

// NewClient 创建并校验 OSS 客户端
func NewClient(cfg Config) (*Client, error) {
	endpoint := strings.TrimSpace(cfg.Endpoint)
	endpoint = strings.TrimPrefix(endpoint, "https://")
	endpoint = strings.TrimPrefix(endpoint, "http://")
	endpoint = strings.TrimRight(endpoint, "/")

	bucket := strings.TrimSpace(cfg.Bucket)
	ak := strings.TrimSpace(cfg.AccessKeyID)
	sk := strings.TrimSpace(cfg.AccessKeySecret)

	if endpoint == "" || bucket == "" || ak == "" || sk == "" {
		return nil, errors.New("OSS 配置不完整：endpoint / bucket / access_key_id / access_key_secret 均不能为空")
	}

	prefix := strings.Trim(strings.TrimSpace(cfg.Prefix), "/")
	publicBase := strings.TrimRight(strings.TrimSpace(cfg.PublicBaseURL), "/")
	if publicBase == "" {
		publicBase = fmt.Sprintf("http://%s.%s", bucket, endpoint)
	}

	return &Client{
		endpoint:        endpoint,
		bucket:          bucket,
		accessKeyID:     ak,
		accessKeySecret: sk,
		prefix:          prefix,
		publicBaseURL:   publicBase,
		httpClient: &http.Client{
			Timeout: 60 * time.Second,
		},
	}, nil
}

// ObjectKey 根据业务相对路径生成完整 Object Key（如 uploads/h2/xxx.jpg）
func (c *Client) ObjectKey(relPath string) string {
	clean := strings.TrimLeft(strings.ReplaceAll(relPath, "\\", "/"), "/")
	if c.prefix == "" {
		return clean
	}
	if clean == "" {
		return c.prefix
	}
	return path.Join(c.prefix, clean)
}

// PublicURL 返回对象公开访问 URL（支持默认 OSS 域名或自定义 CDN 域名）
func (c *Client) PublicURL(objectKey string) string {
	clean := strings.TrimLeft(objectKey, "/")
	return c.publicBaseURL + "/" + clean
}

// PutObject 上传对象流并返回公开访问地址
func (c *Client) PutObject(ctx context.Context, objectKey string, body io.Reader, size int64, contentType string) (string, error) {
	key := strings.TrimLeft(objectKey, "/")
	if key == "" {
		return "", errors.New("objectKey 不能为空")
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	dateStr := time.Now().UTC().Format(http.TimeFormat)
	cacheControl := "public, max-age=31536000, immutable"

	resource := fmt.Sprintf("/%s/%s", c.bucket, key)
	stringToSign := fmt.Sprintf("PUT\n\n%s\n%s\n%s", contentType, dateStr, resource)

	mac := hmac.New(sha1.New, []byte(c.accessKeySecret))
	_, _ = mac.Write([]byte(stringToSign))
	signature := base64.StdEncoding.EncodeToString(mac.Sum(nil))

	uploadURL := fmt.Sprintf("https://%s.%s/%s", c.bucket, c.endpoint, key)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, uploadURL, body)
	if err != nil {
		return "", err
	}
	if size >= 0 {
		req.ContentLength = size
	}
	req.Header.Set("Date", dateStr)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Cache-Control", cacheControl)
	req.Header.Set("Authorization", fmt.Sprintf("OSS %s:%s", c.accessKeyID, signature))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		errBytes, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		return "", fmt.Errorf("OSS 上传失败 (HTTP %d): %s", resp.StatusCode, strings.TrimSpace(string(errBytes)))
	}

	return c.PublicURL(key), nil
}

// ContentTypeByExt 根据归一化扩展名返回标准 MIME 类型
func ContentTypeByExt(ext string) string {
	switch strings.ToLower(strings.TrimPrefix(ext, ".")) {
	case "jpg", "jpeg":
		return "image/jpeg"
	case "png":
		return "image/png"
	case "webp":
		return "image/webp"
	case "heic":
		return "image/heic"
	case "gif":
		return "image/gif"
	case "mp4":
		return "video/mp4"
	case "mov":
		return "video/quicktime"
	default:
		return "application/octet-stream"
	}
}
