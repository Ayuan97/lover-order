package wechat

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"love-order-backend/internal/config"
)

// Code2SessionResponse 微信code2session响应
type Code2SessionResponse struct {
	OpenID     string `json:"openid"`
	SessionKey string `json:"session_key"`
	UnionID    string `json:"unionid"`
	ErrCode    int    `json:"errcode"`
	ErrMsg     string `json:"errmsg"`
}

// UserInfo 微信用户信息
type UserInfo struct {
	OpenID    string `json:"openId"`
	NickName  string `json:"nickName"`
	Gender    int    `json:"gender"`
	City      string `json:"city"`
	Province  string `json:"province"`
	Country   string `json:"country"`
	AvatarUrl string `json:"avatarUrl"`
	Language  string `json:"language"`
}

// WechatClient 微信客户端
type WechatClient struct {
	AppID     string
	AppSecret string
	client    *http.Client
}

// NewWechatClient 创建微信客户端
func NewWechatClient() *WechatClient {
	cfg := config.AppConfig
	return &WechatClient{
		AppID:     cfg.Wechat.AppID,
		AppSecret: cfg.Wechat.AppSecret,
		client: &http.Client{
			Timeout: 30 * time.Second, // 增加超时时间到30秒
		},
	}
}

// Code2Session 通过code获取session_key和openid
func (w *WechatClient) Code2Session(code string) (*Code2SessionResponse, error) {
	url := fmt.Sprintf("https://api.weixin.qq.com/sns/jscode2session?appid=%s&secret=%s&js_code=%s&grant_type=authorization_code",
		w.AppID, w.AppSecret, code)

	resp, err := w.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to request wechat api: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %v", err)
	}

	var result Code2SessionResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %v", err)
	}

	if result.ErrCode != 0 {
		return nil, fmt.Errorf("wechat api error: %d - %s", result.ErrCode, result.ErrMsg)
	}

	// 添加调试日志查看微信API返回的内容
	fmt.Printf("微信API返回: OpenID=%s, UnionID=%s, SessionKey存在=%t\n",
		result.OpenID, result.UnionID, result.SessionKey != "")

	return &result, nil
}

// DecryptUserInfo 解密用户信息（如果需要）
func (w *WechatClient) DecryptUserInfo(encryptedData, iv, sessionKey string) (*UserInfo, error) {
	// 这里需要实现AES解密逻辑
	// 由于涉及到加密解密，暂时返回空实现
	// 在实际项目中，你需要实现AES-128-CBC解密
	return nil, fmt.Errorf("decrypt user info not implemented yet")
}

// ValidateSignature 验证数据签名
func (w *WechatClient) ValidateSignature(rawData, signature, sessionKey string) bool {
	// 这里需要实现SHA1签名验证逻辑
	// 在实际项目中，你需要实现签名验证
	return true // 暂时返回true
}

// GetAccessToken 获取access_token（如果需要调用其他微信API）
func (w *WechatClient) GetAccessToken() (string, error) {
	url := fmt.Sprintf("https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=%s&secret=%s",
		w.AppID, w.AppSecret)

	resp, err := w.client.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to request access token: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response body: %v", err)
	}

	var result struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		ErrCode     int    `json:"errcode"`
		ErrMsg      string `json:"errmsg"`
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return "", fmt.Errorf("failed to unmarshal response: %v", err)
	}

	if result.ErrCode != 0 {
		return "", fmt.Errorf("wechat api error: %d - %s", result.ErrCode, result.ErrMsg)
	}

	return result.AccessToken, nil
}
