-- Love Order 数据库初始化脚本
-- 创建时间: 2025-10-10
-- 版本: 1.0.0

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `love_order`
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE `love_order`;

-- ========================================
-- 1. 家庭表 (families)
-- ========================================
CREATE TABLE IF NOT EXISTS `families` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '家庭ID',
  `name` VARCHAR(100) NOT NULL COMMENT '家庭名称',
  `invite_code` VARCHAR(20) DEFAULT NULL COMMENT '邀请码',
  `avatar` VARCHAR(500) DEFAULT NULL COMMENT '家庭头像',
  `description` TEXT DEFAULT NULL COMMENT '家庭描述',
  `created_by` INT UNSIGNED NOT NULL COMMENT '创建者ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_invite_code` (`invite_code`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭表';

-- ========================================
-- 2. 用户表 (users)
-- ========================================
CREATE TABLE IF NOT EXISTS `users` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `openid` VARCHAR(100) NOT NULL COMMENT '微信openid',
  `unionid` VARCHAR(100) DEFAULT NULL COMMENT '微信unionid',
  `nickname` VARCHAR(100) DEFAULT NULL COMMENT '昵称',
  `avatar` VARCHAR(500) DEFAULT NULL COMMENT '头像URL',
  `phone` VARCHAR(20) DEFAULT NULL COMMENT '手机号',
  `gender` TINYINT DEFAULT 0 COMMENT '性别：0未知，1男，2女',
  `role` ENUM('admin','member','guest') DEFAULT 'member' COMMENT '角色',
  `family_id` INT UNSIGNED DEFAULT NULL COMMENT '家庭ID',
  `guest_expires_at` DATETIME DEFAULT NULL COMMENT '访客过期时间',
  `last_login_at` DATETIME DEFAULT NULL COMMENT '最后登录时间',
  `is_active` TINYINT(1) DEFAULT 1 COMMENT '是否激活',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_openid` (`openid`),
  KEY `idx_family_id` (`family_id`),
  KEY `idx_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_users_family` FOREIGN KEY (`family_id`) REFERENCES `families` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ========================================
-- 3. 菜谱分类表 (recipe_categories)
-- ========================================
CREATE TABLE IF NOT EXISTS `recipe_categories` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类ID',
  `name` VARCHAR(50) NOT NULL COMMENT '分类名称',
  `icon` VARCHAR(200) DEFAULT NULL COMMENT '分类图标URL',
  `color` VARCHAR(20) DEFAULT '#FF8A65' COMMENT '分类颜色',
  `sort_order` INT DEFAULT 0 COMMENT '排序权重',
  `family_id` INT UNSIGNED NOT NULL COMMENT '家庭ID',
  `is_active` TINYINT(1) DEFAULT 1 COMMENT '是否启用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  KEY `idx_family_id` (`family_id`),
  KEY `idx_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_categories_family` FOREIGN KEY (`family_id`) REFERENCES `families` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='菜谱分类表';

-- ========================================
-- 4. 菜谱表 (recipes)
-- ========================================
CREATE TABLE IF NOT EXISTS `recipes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '菜谱ID',
  `name` VARCHAR(100) NOT NULL COMMENT '菜品名称',
  `description` TEXT DEFAULT NULL COMMENT '菜品描述',
  `image` VARCHAR(500) DEFAULT NULL COMMENT '菜品主图',
  `images` JSON DEFAULT NULL COMMENT '菜品图片集合',
  `price` DECIMAL(10,2) DEFAULT 0.00 COMMENT '虚拟价格',
  `category_id` INT UNSIGNED DEFAULT NULL COMMENT '分类ID',
  `cooking_time` INT DEFAULT NULL COMMENT '制作时间（分钟）',
  `difficulty` ENUM('easy','medium','hard') DEFAULT 'easy' COMMENT '制作难度',
  `servings` INT DEFAULT 1 COMMENT '份量（几人份）',
  `ingredients` JSON DEFAULT NULL COMMENT '食材清单',
  `steps` JSON DEFAULT NULL COMMENT '制作步骤',
  `nutrition_info` JSON DEFAULT NULL COMMENT '营养信息',
  `tags` VARCHAR(500) DEFAULT NULL COMMENT '标签（逗号分隔）',
  `family_id` INT UNSIGNED NOT NULL COMMENT '家庭ID',
  `created_by` INT UNSIGNED NOT NULL COMMENT '创建者ID',
  `is_available` TINYINT(1) DEFAULT 1 COMMENT '是否可点餐',
  `is_featured` TINYINT(1) DEFAULT 0 COMMENT '是否推荐',
  `view_count` INT DEFAULT 0 COMMENT '浏览次数',
  `like_count` INT DEFAULT 0 COMMENT '点赞数',
  `order_count` INT DEFAULT 0 COMMENT '被点餐次数',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_family_id` (`family_id`),
  KEY `idx_created_by` (`created_by`),
  KEY `idx_is_available` (`is_available`),
  KEY `idx_is_featured` (`is_featured`),
  KEY `idx_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_recipes_category` FOREIGN KEY (`category_id`) REFERENCES `recipe_categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_recipes_family` FOREIGN KEY (`family_id`) REFERENCES `families` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_recipes_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='菜谱表';

-- ========================================
-- 5. 订单表 (orders)
-- ========================================
CREATE TABLE IF NOT EXISTS `orders` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单ID',
  `order_no` VARCHAR(32) NOT NULL COMMENT '订单号',
  `user_id` INT UNSIGNED NOT NULL COMMENT '下单用户ID',
  `family_id` INT UNSIGNED NOT NULL COMMENT '家庭ID',
  `total_amount` DECIMAL(10,2) DEFAULT 0.00 COMMENT '订单总金额',
  `item_count` INT DEFAULT 0 COMMENT '菜品总数量',
  `status` ENUM('pending','confirmed','cooking','completed','cancelled') DEFAULT 'pending' COMMENT '订单状态',
  `meal_time` DATETIME DEFAULT NULL COMMENT '期望用餐时间',
  `actual_meal_time` DATETIME DEFAULT NULL COMMENT '实际用餐时间',
  `note` TEXT DEFAULT NULL COMMENT '订单备注',
  `is_guest_order` TINYINT(1) DEFAULT 0 COMMENT '是否访客订单',
  `confirmed_by` INT UNSIGNED DEFAULT NULL COMMENT '确认人ID',
  `confirmed_at` DATETIME DEFAULT NULL COMMENT '确认时间',
  `completed_at` DATETIME DEFAULT NULL COMMENT '完成时间',
  `cancelled_at` DATETIME DEFAULT NULL COMMENT '取消时间',
  `cancel_reason` VARCHAR(200) DEFAULT NULL COMMENT '取消原因',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_order_no` (`order_no`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_family_id` (`family_id`),
  KEY `idx_status` (`status`),
  KEY `idx_meal_time` (`meal_time`),
  KEY `idx_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_orders_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_orders_family` FOREIGN KEY (`family_id`) REFERENCES `families` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_orders_confirmed_by` FOREIGN KEY (`confirmed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

-- ========================================
-- 6. 订单详情表 (order_items)
-- ========================================
CREATE TABLE IF NOT EXISTS `order_items` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单详情ID',
  `order_id` INT UNSIGNED NOT NULL COMMENT '订单ID',
  `recipe_id` INT UNSIGNED NOT NULL COMMENT '菜谱ID',
  `recipe_name` VARCHAR(100) NOT NULL COMMENT '菜品名称快照',
  `recipe_image` VARCHAR(500) DEFAULT NULL COMMENT '菜品图片快照',
  `recipe_description` TEXT DEFAULT NULL COMMENT '菜品描述快照',
  `quantity` INT NOT NULL DEFAULT 1 COMMENT '数量',
  `unit_price` DECIMAL(10,2) NOT NULL COMMENT '单价',
  `total_price` DECIMAL(10,2) NOT NULL COMMENT '小计',
  `note` VARCHAR(200) DEFAULT NULL COMMENT '单品备注',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_recipe_id` (`recipe_id`),
  CONSTRAINT `fk_order_items_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_order_items_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `recipes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单详情表';

-- ========================================
-- 7. 收藏表 (favorites)
-- ========================================
CREATE TABLE IF NOT EXISTS `favorites` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
  `user_id` INT UNSIGNED NOT NULL COMMENT '用户ID',
  `recipe_id` INT UNSIGNED NOT NULL COMMENT '菜谱ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_recipe` (`user_id`, `recipe_id`),
  KEY `idx_recipe_id` (`recipe_id`),
  CONSTRAINT `fk_favorites_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_favorites_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `recipes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收藏表';

-- ========================================
-- 8. 菜谱评价表 (recipe_reviews)
-- ========================================
CREATE TABLE IF NOT EXISTS `recipe_reviews` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '评价ID',
  `user_id` INT UNSIGNED NOT NULL COMMENT '评价用户ID',
  `recipe_id` INT UNSIGNED NOT NULL COMMENT '菜谱ID',
  `order_id` INT UNSIGNED DEFAULT NULL COMMENT '关联订单ID',
  `rating` INT NOT NULL COMMENT '评分(1-5分)',
  `comment` TEXT DEFAULT NULL COMMENT '评价内容',
  `images` JSON DEFAULT NULL COMMENT '评价图片',
  `is_anonymous` TINYINT(1) DEFAULT 0 COMMENT '是否匿名评价',
  `reply` TEXT DEFAULT NULL COMMENT '回复内容',
  `replied_by` INT UNSIGNED DEFAULT NULL COMMENT '回复人ID',
  `replied_at` DATETIME DEFAULT NULL COMMENT '回复时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_recipe_id` (`recipe_id`),
  KEY `idx_order_id` (`order_id`),
  KEY `idx_rating` (`rating`),
  KEY `idx_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_reviews_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reviews_recipe` FOREIGN KEY (`recipe_id`) REFERENCES `recipes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_reviews_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_reviews_replied_by` FOREIGN KEY (`replied_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='菜谱评价表';

-- ========================================
-- 9. 家庭邀请表 (family_invitations)
-- ========================================
CREATE TABLE IF NOT EXISTS `family_invitations` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '邀请ID',
  `family_id` INT UNSIGNED NOT NULL COMMENT '家庭ID',
  `invite_code` VARCHAR(50) NOT NULL COMMENT '邀请码',
  `invited_by` INT UNSIGNED NOT NULL COMMENT '邀请人ID',
  `invite_type` ENUM('member','guest') DEFAULT 'guest' COMMENT '邀请类型',
  `expires_at` DATETIME NOT NULL COMMENT '过期时间',
  `max_uses` INT DEFAULT 1 COMMENT '最大使用次数',
  `used_count` INT DEFAULT 0 COMMENT '已使用次数',
  `used_by` JSON DEFAULT NULL COMMENT '使用者ID列表',
  `note` VARCHAR(200) DEFAULT NULL COMMENT '邀请备注',
  `is_active` TINYINT(1) DEFAULT 1 COMMENT '是否有效',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted_at` DATETIME DEFAULT NULL COMMENT '删除时间',
  PRIMARY KEY (`id`),
  KEY `idx_family_id` (`family_id`),
  KEY `idx_invite_code` (`invite_code`),
  KEY `idx_invited_by` (`invited_by`),
  KEY `idx_expires_at` (`expires_at`),
  KEY `idx_deleted_at` (`deleted_at`),
  CONSTRAINT `fk_invitations_family` FOREIGN KEY (`family_id`) REFERENCES `families` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_invitations_invited_by` FOREIGN KEY (`invited_by`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='家庭邀请表';

-- ========================================
-- 插入初始数据（可选）
-- ========================================

-- 插入测试家庭
INSERT INTO `families` (`id`, `name`, `invite_code`, `description`, `created_by`, `created_at`, `updated_at`)
VALUES
(1, '温馨小家', 'FAMILY2024', '我们的幸福之家', 1, NOW(), NOW());

-- 插入测试用户（注意：实际使用需要真实的微信openid）
INSERT INTO `users` (`id`, `openid`, `nickname`, `avatar`, `role`, `family_id`, `is_active`, `created_at`, `updated_at`)
VALUES
(1, 'test_openid_admin', '家庭管理员', 'https://example.com/avatar1.jpg', 'admin', 1, 1, NOW(), NOW()),
(2, 'test_openid_member', '家庭成员', 'https://example.com/avatar2.jpg', 'member', 1, 1, NOW(), NOW());

-- 插入默认菜谱分类
INSERT INTO `recipe_categories` (`name`, `icon`, `color`, `sort_order`, `family_id`, `created_at`, `updated_at`)
VALUES
('家常菜', '🍲', '#FF8A65', 1, 1, NOW(), NOW()),
('汤品', '🥣', '#81C784', 2, 1, NOW(), NOW()),
('主食', '🍚', '#FFB74D', 3, 1, NOW(), NOW()),
('凉菜', '🥗', '#64B5F6', 4, 1, NOW(), NOW()),
('甜品', '🍰', '#F8BBD9', 5, 1, NOW(), NOW());

-- ========================================
-- 创建完成提示
-- ========================================
SELECT '数据库初始化完成！' AS message;
SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = 'love_order';
