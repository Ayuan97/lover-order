package api

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/config"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/pkg/oss"
)

// UploadHandler 媒体上传入口（统一存储至阿里云 OSS）
type UploadHandler struct {
	ossClient *oss.Client
}

// NewUploadHandler 构造
func NewUploadHandler(ossClient *oss.Client) *UploadHandler {
	return &UploadHandler{ossClient: ossClient}
}

// Image 上传图片 multipart/form-data 字段 file
func (h *UploadHandler) Image(c *gin.Context) {
	cfg := config.AppConfig
	if cfg == nil || h.ossClient == nil {
		Fail(c, CodeInternalError, "存储服务未初始化")
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
	subDir := fmt.Sprintf("u%d", uid)
	if hid > 0 {
		subDir = fmt.Sprintf("h%d", hid)
	}

	rnd, err := randomToken(8)
	if err != nil {
		Fail(c, CodeInternalError, "生成名称失败")
		return
	}
	filename := fmt.Sprintf("%d_%s.%s", time.Now().UnixNano(), rnd, ext)

	src, err := file.Open()
	if err != nil {
		Fail(c, CodeInternalError, "读取上传文件失败")
		return
	}
	defer src.Close()

	objectKey := h.ossClient.ObjectKey(fmt.Sprintf("%s/%s", subDir, filename))
	publicURL, err := h.ossClient.PutObject(c.Request.Context(), objectKey, src, file.Size, oss.ContentTypeByExt(ext))
	if err != nil {
		Fail(c, CodeInternalError, "上传 OSS 失败")
		return
	}

	OK(c, gin.H{
		"url":  publicURL,
		"path": publicURL,
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
