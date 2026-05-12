package api

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/config"
	"lover-order-backend/internal/middleware"
)

// UploadHandler 文件上传相关入口
type UploadHandler struct{}

// NewUploadHandler 构造
func NewUploadHandler() *UploadHandler {
	return &UploadHandler{}
}

// Image 上传图片 multipart/form-data 字段 file
func (h *UploadHandler) Image(c *gin.Context) {
	cfg := config.AppConfig
	if cfg == nil {
		Fail(c, CodeInternalError, "配置未初始化")
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		Fail(c, CodeBadRequest, "请选择图片")
		return
	}
	if file.Size > cfg.Upload.MaxSize {
		Fail(c, CodeBadRequest, fmt.Sprintf("图片不能超过 %d MB", cfg.Upload.MaxSize/1024/1024))
		return
	}

	ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(file.Filename)), ".")
	if ext == "jpeg" {
		ext = "jpg"
	}
	if !isAllowedExt(cfg.Upload.AllowedTypes, ext) {
		Fail(c, CodeBadRequest, "不支持的图片格式")
		return
	}

	uid, _ := middleware.CurrentUserID(c)
	hid, _ := middleware.CurrentHouseholdID(c)
	subDir := "u" + fmt.Sprintf("%d", uid)
	if hid > 0 {
		subDir = "h" + fmt.Sprintf("%d", hid)
	}

	saveDir := filepath.Join(cfg.Upload.Path, subDir)
	if err := os.MkdirAll(saveDir, 0o755); err != nil {
		Fail(c, CodeInternalError, "目录创建失败")
		return
	}

	rnd, err := randomToken(8)
	if err != nil {
		Fail(c, CodeInternalError, "生成名称失败")
		return
	}
	filename := fmt.Sprintf("%d_%s.%s", time.Now().UnixNano(), rnd, ext)
	savePath := filepath.Join(saveDir, filename)

	if err := c.SaveUploadedFile(file, savePath); err != nil {
		Fail(c, CodeInternalError, "保存失败")
		return
	}

	scheme := "http"
	if c.Request.TLS != nil {
		scheme = "https"
	}
	url := fmt.Sprintf("%s://%s/static/uploads/%s/%s", scheme, c.Request.Host, subDir, filename)
	OK(c, gin.H{
		"url":  url,
		"path": fmt.Sprintf("/static/uploads/%s/%s", subDir, filename),
	})
}

func isAllowedExt(allowed []string, ext string) bool {
	for _, a := range allowed {
		if strings.ToLower(a) == ext {
			return true
		}
	}
	return false
}

func randomToken(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
