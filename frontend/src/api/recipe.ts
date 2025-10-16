// 菜谱相关API
import { request } from './request'
import { API_ENDPOINTS } from './config'

// 菜谱接口定义
export interface Recipe {
  id: number
  name: string
  description: string
  image?: string
  ingredients: string // 后端返回的是base64编码的JSON字符串
  steps: string // 后端返回的是base64编码的JSON字符串
  cooking_time: number
  servings: number
  difficulty: 'easy' | 'medium' | 'hard'
  tags: string // 后端返回的是逗号分隔的字符串
  category_id: number
  category_name?: string
  is_favorite?: boolean
  created_at: string
  updated_at: string
  // 后端额外字段
  price?: number
  family_id?: number
  created_by?: number
  is_available?: boolean
  is_featured?: boolean
  view_count?: number
  like_count?: number
  order_count?: number
}

// 菜谱列表查询参数
export interface RecipeListParams {
  page?: number
  page_size?: number
  category_id?: number
  keyword?: string
  tags?: string[]
  difficulty?: number
  cooking_time_max?: number
  sort_by?: 'created_at' | 'updated_at' | 'cooking_time' | 'difficulty'
  sort_order?: 'asc' | 'desc'
}

// 菜谱列表响应
export interface RecipeListResponse {
  recipes: Recipe[]
  total: number
  page: number
  page_size: number
  total_pages: number
}

// 创建/更新菜谱参数
export interface CreateRecipeParams {
  name: string
  description: string
  image?: string
  ingredients: string[]
  steps: string[]
  cooking_time: number
  servings: number
  difficulty: number
  tags: string[]
  category_id: number
}

export interface UpdateRecipeParams extends Partial<CreateRecipeParams> {
  id: number
}

// 菜谱API服务
export class RecipeService {
  // 获取菜谱列表
  static async getRecipeList(params?: RecipeListParams): Promise<RecipeListResponse> {
    // 设置默认参数并转换参数名
    const defaultParams = {
      page: 1,
      page_size: 100,
      ...params
    }

    // 转换参数名以匹配后端期望，过滤掉 undefined 值
    const backendParams: any = {
      page: defaultParams.page,
      size: defaultParams.page_size, // 后端期望的是 size 而不是 page_size
    }

    // 只添加有值的参数
    if (defaultParams.category_id !== undefined) {
      backendParams.category_id = defaultParams.category_id
    }
    if (defaultParams.keyword !== undefined && defaultParams.keyword !== '') {
      backendParams.keyword = defaultParams.keyword
    }
    if (defaultParams.tags !== undefined) {
      backendParams.tags = defaultParams.tags
    }
    if (defaultParams.difficulty !== undefined) {
      backendParams.difficulty = defaultParams.difficulty
    }
    if (defaultParams.cooking_time_max !== undefined) {
      backendParams.cooking_time_max = defaultParams.cooking_time_max
    }
    if (defaultParams.sort_by !== undefined && defaultParams.sort_by !== '') {
      backendParams.sort_by = defaultParams.sort_by
    }
    if (defaultParams.sort_order !== undefined && defaultParams.sort_order !== '') {
      backendParams.sort_order = defaultParams.sort_order
    }

    // 使用正式的认证接口，确保获取到当前用户家庭的菜谱
    const response = await request.get<RecipeListResponse>(API_ENDPOINTS.RECIPES.LIST, backendParams)

    // 后端返回的格式可能是 {data: {...}} 或直接是数据对象
    const responseData = response.data.data || response.data

    return {
      recipes: responseData.list || responseData.recipes || [],
      total: responseData.total || 0,
      page: responseData.page || 1,
      page_size: responseData.size || responseData.page_size || 10,
      total_pages: Math.ceil((responseData.total || 0) / (responseData.size || responseData.page_size || 10))
    }
  }

  // 获取菜谱详情
  static async getRecipeDetail(id: number): Promise<Recipe> {
    const response = await request.get<Recipe>(API_ENDPOINTS.RECIPES.DETAIL(id))
    return response.data
  }

  // 创建菜谱
  static async createRecipe(params: CreateRecipeParams): Promise<Recipe> {
    const response = await request.post<Recipe>(API_ENDPOINTS.RECIPES.CREATE, params)
    return response.data
  }

  // 更新菜谱
  static async updateRecipe(params: UpdateRecipeParams): Promise<Recipe> {
    const { id, ...updateData } = params
    const response = await request.put<Recipe>(API_ENDPOINTS.RECIPES.UPDATE(id), updateData)
    return response.data
  }

  // 删除菜谱
  static async deleteRecipe(id: number): Promise<void> {
    await request.delete(API_ENDPOINTS.RECIPES.DELETE(id))
  }

  // 切换收藏状态
  static async toggleFavorite(id: number): Promise<{ is_favorite: boolean }> {
    const response = await request.post<{ is_favorite: boolean }>(API_ENDPOINTS.RECIPES.TOGGLE_FAVORITE(id))
    return response.data
  }

  // 获取收藏的菜谱
  static async getFavoriteRecipes(params?: Omit<RecipeListParams, 'category_id'>): Promise<RecipeListResponse> {
    const response = await request.get<RecipeListResponse>(API_ENDPOINTS.RECIPES.FAVORITES, params)
    return response.data
  }
}

// 分类相关接口
export interface Category {
  id: number
  name: string
  description: string
  icon?: string
  sort_order: number
  recipe_count: number
  created_at: string
  updated_at: string
}

// 分类统计
export interface CategoryStats {
  total_categories: number
  total_recipes: number
  categories: Array<{
    id: number
    name: string
    recipe_count: number
    favorite_count: number
  }>
}

// 分类API服务
export class CategoryService {
  // 获取分类列表
  static async getCategoryList(): Promise<Category[]> {
    // 使用正式的认证接口
    const response = await request.get<Category[]>(API_ENDPOINTS.CATEGORIES.LIST)

    // 处理响应格式
    if (response.data && response.data.data && Array.isArray(response.data.data)) {
      return response.data.data
    }

    // 如果是直接的数组格式
    if (Array.isArray(response.data)) {
      return response.data
    }

    return []
  }

  // 获取分类详情
  static async getCategoryDetail(id: number): Promise<Category> {
    const response = await request.get<Category>(API_ENDPOINTS.CATEGORIES.DETAIL(id))
    return response.data
  }

  // 获取分类统计
  static async getCategoryStats(): Promise<CategoryStats> {
    const response = await request.get<CategoryStats>(API_ENDPOINTS.CATEGORIES.STATS)
    return response.data
  }

  // 创建分类（管理员功能）
  static async createCategory(params: { name: string; description: string; icon?: string }): Promise<Category> {
    const response = await request.post<Category>(API_ENDPOINTS.CATEGORIES.CREATE, params)
    return response.data
  }

  // 更新分类（管理员功能）
  static async updateCategory(id: number, params: { name?: string; description?: string; icon?: string }): Promise<Category> {
    const response = await request.put<Category>(API_ENDPOINTS.CATEGORIES.UPDATE(id), params)
    return response.data
  }

  // 删除分类（管理员功能）
  static async deleteCategory(id: number): Promise<void> {
    await request.delete(API_ENDPOINTS.CATEGORIES.DELETE(id))
  }

  // 更新分类排序（管理员功能）
  static async updateCategorySortOrder(categories: Array<{ id: number; sort_order: number }>): Promise<void> {
    await request.put(API_ENDPOINTS.CATEGORIES.SORT, { categories })
  }
}

// 导出默认服务
export default {
  RecipeService,
  CategoryService
}
