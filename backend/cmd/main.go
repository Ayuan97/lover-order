package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"love-order-backend/internal/api"
	"love-order-backend/internal/config"
	"love-order-backend/internal/middleware"
	"love-order-backend/internal/model"

	"github.com/gin-gonic/gin"
)

func main() {
	// 加载配置
	cfg := config.LoadConfig("config.yaml")

	// 设置Gin模式
	gin.SetMode(cfg.Server.Mode)

	// 初始化数据库
	_, err := model.InitDB(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer model.CloseDB()

	// 自动迁移数据库表结构
	if err := model.AutoMigrate(); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// 创建Gin引擎
	r := gin.New()

	// 添加中间件
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// 添加CORS中间件
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	})

	// 健康检查接口
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": "Love Order Backend is running",
			"version": "1.0.0",
		})
	})

	// 创建处理器
	authHandler := api.NewAuthHandler()
	recipeHandler := api.NewRecipeHandler()
	categoryHandler := api.NewCategoryHandler()
	orderHandler := api.NewOrderHandler()
	guestHandler := api.NewGuestHandler()
	familyHandler := api.NewFamilyHandler()

	// API路由组
	apiV1 := r.Group("/api/v1")
	{
		// 认证相关路由（无需认证）
		auth := apiV1.Group("/auth")
		{
			auth.POST("/wechat/login", authHandler.WechatLogin)
			auth.POST("/refresh", authHandler.RefreshToken)
			auth.POST("/logout", authHandler.Logout)
		}

		// 访客相关路由（无需认证）
		guest := apiV1.Group("/guest")
		{
			guest.GET("/invite/check", guestHandler.CheckInviteCode)
			guest.POST("/register", guestHandler.GuestRegister)
		}

		// 开发测试路由（无需认证，仅用于开发测试）
		dev := apiV1.Group("/dev")
		{
			dev.GET("/categories", categoryHandler.GetCategoryListDev)
			dev.GET("/recipes", recipeHandler.GetRecipeListDev)
			dev.POST("/categories", categoryHandler.CreateCategoryDev)
			dev.POST("/recipes", recipeHandler.CreateRecipeDev)
		}

		// 需要认证的路由
		authenticated := apiV1.Group("")
		authenticated.Use(middleware.AuthMiddleware())
		{
			// 用户相关路由
			user := authenticated.Group("/user")
			{
				user.GET("/profile", authHandler.GetProfile)
				user.PUT("/profile", authHandler.UpdateProfile)
				user.GET("/family/members", middleware.FamilyMemberMiddleware(), authHandler.GetFamilyMembers)
			}

			// 管理员功能路由
			admin := authenticated.Group("/admin")
			admin.Use(middleware.AdminMiddleware())
			{
				admin.PUT("/member/role", authHandler.UpdateMemberRole)
				admin.POST("/member/deactivate", authHandler.DeactivateMember)
			}

			// 菜谱相关路由
			recipes := authenticated.Group("/recipes")
			recipes.Use(middleware.FamilyMemberMiddleware())
			{
				recipes.GET("", recipeHandler.GetRecipeList)
				recipes.POST("", recipeHandler.CreateRecipe)
				recipes.GET("/:id", recipeHandler.GetRecipeDetail)
				recipes.PUT("/:id", recipeHandler.UpdateRecipe)
				recipes.DELETE("/:id", recipeHandler.DeleteRecipe)
				recipes.POST("/:id/favorite", recipeHandler.ToggleFavorite)
				recipes.GET("/favorites", recipeHandler.GetFavoriteRecipes)
			}

			// 菜谱分类相关路由
			categories := authenticated.Group("/categories")
			categories.Use(middleware.FamilyMemberMiddleware())
			{
				categories.GET("", categoryHandler.GetCategoryList)
				categories.GET("/:id", categoryHandler.GetCategoryDetail)
				categories.GET("/stats", categoryHandler.GetCategoryStats)

				// 管理员功能
				adminCategories := categories.Group("")
				adminCategories.Use(middleware.AdminMiddleware())
				{
					adminCategories.POST("", categoryHandler.CreateCategory)
					adminCategories.PUT("/:id", categoryHandler.UpdateCategory)
					adminCategories.DELETE("/:id", categoryHandler.DeleteCategory)
					adminCategories.PUT("/sort", categoryHandler.UpdateCategorySortOrder)
				}
			}

			// 订单相关路由
			orders := authenticated.Group("/orders")
			orders.Use(middleware.FamilyMemberMiddleware())
			{
				orders.GET("", orderHandler.GetOrderList)
				orders.POST("", orderHandler.CreateOrder)
				orders.GET("/:id", orderHandler.GetOrderDetail)
				orders.PUT("/:id/status", orderHandler.UpdateOrderStatus)
				orders.POST("/:id/cancel", orderHandler.CancelOrder)
				orders.POST("/:id/repeat", orderHandler.RepeatOrder)
				orders.GET("/stats", orderHandler.GetOrderStats)
				orders.GET("/summary", orderHandler.GetUserOrderSummary)

				// 管理员功能
				adminOrders := orders.Group("")
				adminOrders.Use(middleware.AdminMiddleware())
				{
					adminOrders.GET("/today", orderHandler.GetTodayOrders)
					adminOrders.GET("/pending", orderHandler.GetPendingOrders)
				}
			}

			// 家庭管理路由
			family := authenticated.Group("/family")
			{
				family.POST("", familyHandler.CreateFamily)
				family.GET("/info", middleware.FamilyMemberMiddleware(), familyHandler.GetFamilyInfo)
				family.PUT("/info", middleware.FamilyMemberMiddleware(), middleware.AdminMiddleware(), familyHandler.UpdateFamily)
				family.POST("/join", familyHandler.JoinFamily)
				family.POST("/leave", middleware.FamilyMemberMiddleware(), familyHandler.LeaveFamily)
				family.DELETE("", middleware.FamilyMemberMiddleware(), middleware.AdminMiddleware(), familyHandler.DeleteFamily)
				family.GET("/stats", middleware.FamilyMemberMiddleware(), familyHandler.GetFamilyStats)
			}

			// 访客管理路由
			guestManagement := authenticated.Group("/guest")
			{
				guestManagement.GET("/info", guestHandler.GetGuestInfo)

				// 管理员功能
				adminGuest := guestManagement.Group("")
				adminGuest.Use(middleware.FamilyMemberMiddleware(), middleware.AdminMiddleware())
				{
					adminGuest.POST("/invite", guestHandler.GenerateInviteCode)
					adminGuest.GET("/list", guestHandler.GetFamilyGuests)
					adminGuest.GET("/invitations", guestHandler.GetInvitationList)
					adminGuest.PUT("/:id/extend", guestHandler.ExtendGuestPermission)
					adminGuest.POST("/:id/revoke", guestHandler.RevokeGuestPermission)
				}
			}
		}
	}

	// 启动服务器
	port := fmt.Sprintf(":%d", cfg.Server.Port)
	log.Printf("Love Order Backend starting on port %d", cfg.Server.Port)
	log.Printf("Health check: http://localhost%s/health", port)
	log.Printf("API base URL: http://localhost%s/api/v1", port)

	// 优雅关闭
	go func() {
		if err := r.Run(port); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// 等待中断信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	log.Println("Server stopped")
}
