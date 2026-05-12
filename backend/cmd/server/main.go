package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"lover-order-backend/internal/api"
	"lover-order-backend/internal/config"
	"lover-order-backend/internal/middleware"
	"lover-order-backend/internal/model"
)

func main() {
	cfg := config.LoadConfig("config.yaml")
	gin.SetMode(cfg.Server.Mode)

	if _, err := model.InitDB(cfg); err != nil {
		log.Fatalf("数据库初始化失败：%v", err)
	}
	defer model.CloseDB()

	if err := model.AutoMigrate(); err != nil {
		log.Fatalf("数据库迁移失败：%v", err)
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery(), corsMiddleware(cfg))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	registerRoutes(r)

	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	srv := &http.Server{Addr: addr, Handler: r}

	go func() {
		log.Printf("lover-order backend 启动在 %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("启动失败：%v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("正在关闭服务...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("关闭异常：%v", err)
	}
}

func registerRoutes(r *gin.Engine) {
	authH := api.NewAuthHandler()
	householdH := api.NewHouseholdHandler()
	categoryH := api.NewCategoryHandler()
	recipeH := api.NewRecipeHandler()
	mealH := api.NewMealHandler()

	v1 := r.Group("/api/v1")
	{
		auth := v1.Group("/auth")
		{
			auth.POST("/apple", authH.AppleLogin)
			auth.POST("/refresh", authH.Refresh)
			auth.POST("/logout", authH.Logout)
		}

		secured := v1.Group("")
		secured.Use(middleware.AuthRequired())
		{
			user := secured.Group("/user")
			{
				user.GET("/profile", authH.Profile)
				user.POST("/profile", authH.UpdateProfile)
			}

			household := secured.Group("/household")
			{
				household.POST("/create", householdH.Create)
				household.POST("/join", householdH.Join)
				household.POST("/leave", householdH.Leave)
				household.GET("/info", middleware.HouseholdRequired(), householdH.Info)
				household.POST("/invite", middleware.HouseholdRequired(), householdH.Invite)
				household.GET("/invitations", middleware.HouseholdRequired(), householdH.Invitations)
			}

			inHousehold := secured.Group("")
			inHousehold.Use(middleware.HouseholdRequired())
			{
				categories := inHousehold.Group("/categories")
				{
					categories.GET("/list", categoryH.List)
					categories.POST("/create", categoryH.Create)
					categories.POST("/:id/update", categoryH.Update)
					categories.POST("/:id/delete", categoryH.Delete)
				}

				recipes := inHousehold.Group("/recipes")
				{
					recipes.GET("/list", recipeH.List)
					recipes.GET("/:id", recipeH.Detail)
					recipes.POST("/create", recipeH.Create)
					recipes.POST("/:id/update", recipeH.Update)
					recipes.POST("/:id/delete", recipeH.Delete)
					recipes.POST("/:id/favorite", recipeH.ToggleFavorite)
				}

				meals := inHousehold.Group("/meals")
				{
					meals.GET("/current", mealH.Current)
					meals.GET("/list", mealH.List)
					meals.GET("/:id", mealH.Detail)
					meals.POST("/create", mealH.Create)
					meals.POST("/:id/update", mealH.Update)
					meals.POST("/:id/confirm", mealH.Confirm)
					meals.POST("/:id/complete", mealH.Complete)
					meals.POST("/:id/cancel", mealH.Cancel)
					meals.POST("/:id/review", mealH.Review)
					meals.POST("/:id/dishes/add", mealH.AddDish)
					meals.POST("/:id/dishes/:dish_id/remove", mealH.RemoveDish)
				}
			}
		}
	}
}

func corsMiddleware(cfg *config.Config) gin.HandlerFunc {
	allowOrigins := "*"
	if len(cfg.CORS.AllowOrigins) > 0 && cfg.CORS.AllowOrigins[0] != "*" {
		allowOrigins = cfg.CORS.AllowOrigins[0]
	}
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", allowOrigins)
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
