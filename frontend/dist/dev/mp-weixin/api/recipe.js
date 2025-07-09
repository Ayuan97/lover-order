"use strict";
const api_request = require("./request.js");
const api_config = require("./config.js");
class RecipeService {
  // 获取菜谱列表
  static async getRecipeList(params) {
    const defaultParams = {
      page: 1,
      page_size: 100,
      ...params
    };
    const backendParams = {
      page: defaultParams.page,
      size: defaultParams.page_size
      // 后端期望的是 size 而不是 page_size
    };
    if (defaultParams.category_id !== void 0) {
      backendParams.category_id = defaultParams.category_id;
    }
    if (defaultParams.keyword !== void 0 && defaultParams.keyword !== "") {
      backendParams.keyword = defaultParams.keyword;
    }
    if (defaultParams.tags !== void 0) {
      backendParams.tags = defaultParams.tags;
    }
    if (defaultParams.difficulty !== void 0) {
      backendParams.difficulty = defaultParams.difficulty;
    }
    if (defaultParams.cooking_time_max !== void 0) {
      backendParams.cooking_time_max = defaultParams.cooking_time_max;
    }
    if (defaultParams.sort_by !== void 0 && defaultParams.sort_by !== "") {
      backendParams.sort_by = defaultParams.sort_by;
    }
    if (defaultParams.sort_order !== void 0 && defaultParams.sort_order !== "") {
      backendParams.sort_order = defaultParams.sort_order;
    }
    try {
      const response = await api_request.request.get(api_config.API_ENDPOINTS.DEV.RECIPES, backendParams);
      const responseData = response.data.data || response.data;
      return {
        recipes: responseData.list || [],
        total: responseData.total || 0,
        page: responseData.page || 1,
        page_size: responseData.size || 10,
        total_pages: Math.ceil((responseData.total || 0) / (responseData.size || 10))
      };
    } catch (error) {
      const response = await api_request.request.get(api_config.API_ENDPOINTS.RECIPES.LIST, backendParams);
      return response.data;
    }
  }
  // 获取菜谱详情
  static async getRecipeDetail(id) {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.RECIPES.DETAIL(id));
    return response.data;
  }
  // 创建菜谱
  static async createRecipe(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.RECIPES.CREATE, params);
    return response.data;
  }
  // 更新菜谱
  static async updateRecipe(params) {
    const { id, ...updateData } = params;
    const response = await api_request.request.put(api_config.API_ENDPOINTS.RECIPES.UPDATE(id), updateData);
    return response.data;
  }
  // 删除菜谱
  static async deleteRecipe(id) {
    await api_request.request.delete(api_config.API_ENDPOINTS.RECIPES.DELETE(id));
  }
  // 切换收藏状态
  static async toggleFavorite(id) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.RECIPES.TOGGLE_FAVORITE(id));
    return response.data;
  }
  // 获取收藏的菜谱
  static async getFavoriteRecipes(params) {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.RECIPES.FAVORITES, params);
    return response.data;
  }
}
class CategoryService {
  // 获取分类列表
  static async getCategoryList() {
    try {
      const response = await api_request.request.get(api_config.API_ENDPOINTS.DEV.CATEGORIES);
      if (response.data && response.data.data && Array.isArray(response.data.data)) {
        return response.data.data;
      }
      if (Array.isArray(response.data)) {
        return response.data;
      }
      return [];
    } catch (error) {
      const response = await api_request.request.get(api_config.API_ENDPOINTS.CATEGORIES.LIST);
      return response.data;
    }
  }
  // 获取分类详情
  static async getCategoryDetail(id) {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.CATEGORIES.DETAIL(id));
    return response.data;
  }
  // 获取分类统计
  static async getCategoryStats() {
    const response = await api_request.request.get(api_config.API_ENDPOINTS.CATEGORIES.STATS);
    return response.data;
  }
  // 创建分类（管理员功能）
  static async createCategory(params) {
    const response = await api_request.request.post(api_config.API_ENDPOINTS.CATEGORIES.CREATE, params);
    return response.data;
  }
  // 更新分类（管理员功能）
  static async updateCategory(id, params) {
    const response = await api_request.request.put(api_config.API_ENDPOINTS.CATEGORIES.UPDATE(id), params);
    return response.data;
  }
  // 删除分类（管理员功能）
  static async deleteCategory(id) {
    await api_request.request.delete(api_config.API_ENDPOINTS.CATEGORIES.DELETE(id));
  }
  // 更新分类排序（管理员功能）
  static async updateCategorySortOrder(categories) {
    await api_request.request.put(api_config.API_ENDPOINTS.CATEGORIES.SORT, { categories });
  }
}
exports.CategoryService = CategoryService;
exports.RecipeService = RecipeService;
