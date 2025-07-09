// 模拟数据服务
import type { Recipe, Category, RecipeListResponse } from './recipe'

// 模拟分类数据
export const mockCategories: Category[] = [
  {
    id: 1,
    name: '热门推荐',
    description: '最受欢迎的家常菜',
    icon: '🔥',
    sort_order: 1,
    recipe_count: 8,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z'
  },
  {
    id: 2,
    name: '汤品',
    description: '营养美味的汤类',
    icon: '🍲',
    sort_order: 2,
    recipe_count: 6,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z'
  },
  {
    id: 3,
    name: '素食',
    description: '健康清淡的素食菜品',
    icon: '🥬',
    sort_order: 3,
    recipe_count: 5,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z'
  },
  {
    id: 4,
    name: '甜品',
    description: '美味的甜点和饮品',
    icon: '🍰',
    sort_order: 4,
    recipe_count: 4,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z'
  },
  {
    id: 5,
    name: '川菜',
    description: '麻辣鲜香的川式菜品',
    icon: '🌶️',
    sort_order: 5,
    recipe_count: 7,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z'
  },
  {
    id: 6,
    name: '粤菜',
    description: '清淡鲜美的广式菜品',
    icon: '🦐',
    sort_order: 6,
    recipe_count: 6,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z'
  }
]

// 模拟菜谱数据
export const mockRecipes: Recipe[] = [
  // 热门推荐
  {
    id: 1,
    name: '红烧肉',
    description: '肥而不腻，入口即化的经典红烧肉',
    image: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgdmlld0JveD0iMCAwIDIwMCAyMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIyMDAiIGhlaWdodD0iMjAwIiByeD0iMTIiIGZpbGw9IiNGRkY1RjUiLz4KPHN2ZyB4PSI3NSIgeT0iNzUiIHdpZHRoPSI1MCIgaGVpZ2h0PSI1MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSIjRkY2OTQ3Ii8+Cjwvc3ZnPgo8L3N2Zz4=',
    ingredients: 'WyLkupTohKnogYkiLCLlhpnogZciLCLnlJ/mir4iLCLogIHmirQiLCLmlpnmlosiLCLnlJ/mir7ph4wiLCLlhpnphJoiLCLnlJ/lkJsiXQ==',
    steps: 'WyLkupTohKnogYnliIfmiJDlnZfnirbvvIzlhYXmsLTngavnhKYiLCLngavkuK3mlL7msrnoibLvvIznhLblkI7mjbfotbciLCLliqDlhaXosIPmlpnmlosiLCLliqDlhaXnlJ/mir7lkozlhpnphJoiLCLlsI/ngavmhLLnhKbvvIzmlLbmsrnoibLlkI7ljbPlj6/lh7rplYUiXQ==',
    cooking_time: 60,
    servings: 4,
    difficulty: 'medium',
    tags: '川菜,家常菜,下饭菜',
    category_id: 1,
    category_name: '热门推荐',
    is_favorite: true,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
    price: 25.8,
    family_id: 1,
    created_by: 1,
    is_available: true,
    is_featured: true,
    view_count: 156,
    like_count: 89,
    order_count: 45
  },
  {
    id: 2,
    name: '宫保鸡丁',
    description: '酸甜微辣，嫩滑爽口的经典川菜',
    image: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgdmlld0JveD0iMCAwIDIwMCAyMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIyMDAiIGhlaWdodD0iMjAwIiByeD0iMTIiIGZpbGw9IiNGRkY1RjUiLz4KPHN2ZyB4PSI3NSIgeT0iNzUiIHdpZHRoPSI1MCIgaGVpZ2h0PSI1MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSIjRkZDMTA3Ii8+Cjwvc3ZnPgo8L3N2Zz4=',
    ingredients: 'WyLpuKHohbgiLCLoi7HnsbMiLCLlubLojbciLCLlubLojbciLCLlubLojbciLCLlubLojbciLCLlubLojbciLCLlubLojbciXQ==',
    steps: 'WyLpuKHohbjogoLliIfkuIHvvIzliqDlhaXosIPmlpnmlosiLCLngavkuK3mlL7msrnoibLvvIznhLblkI7mjbfotbciLCLliqDlhaXnlJ/mir7lkozlhpnphJoiLCLlsI/ngavmhLLnhKbvvIzmlLbmsrnoibLlkI7ljbPlj6/lh7rplYUiXQ==',
    cooking_time: 25,
    servings: 3,
    difficulty: 'medium',
    tags: '川菜,家常菜,下饭菜',
    category_id: 1,
    category_name: '热门推荐',
    is_favorite: false,
    created_at: '2024-01-02T00:00:00Z',
    updated_at: '2024-01-02T00:00:00Z',
    price: 22.8,
    family_id: 1,
    created_by: 1,
    is_available: true,
    is_featured: true,
    view_count: 134,
    like_count: 76,
    order_count: 38
  },
  {
    id: 3,
    name: '糖醋里脊',
    description: '酸甜可口，外酥内嫩的经典菜品',
    image: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgdmlld0JveD0iMCAwIDIwMCAyMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIyMDAiIGhlaWdodD0iMjAwIiByeD0iMTIiIGZpbGw9IiNGRkY1RjUiLz4KPHN2ZyB4PSI3NSIgeT0iNzUiIHdpZHRoPSI1MCIgaGVpZ2h0PSI1MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSIjRkY1MDcyIi8+Cjwvc3ZnPgo8L3N2Zz4=',
    ingredients: 'WyLnjKrph4zogrIiLCLnlJ/mir4iLCLph4zoibIiLCLnlJ/lkJsiLCLnlJ/mir7ph4wiLCLnlJ/lkJsiXQ==',
    steps: 'WyLnjKrph4zogrLliIfmnaHvvIzohZPlkIbosIPmlpnmlosiLCLosIPnlJ/mir7ph4zlkozph4zoibLosIPmiJDnlJ/ph4zoibLmsrnoibIiLCLngavkuK3mlL7msrnoibLvvIznhLblkI7mjbfotbciXQ==',
    cooking_time: 30,
    servings: 3,
    difficulty: 'medium',
    tags: '酸甜,家常菜,下饭菜',
    category_id: 1,
    category_name: '热门推荐',
    is_favorite: true,
    created_at: '2024-01-03T00:00:00Z',
    updated_at: '2024-01-03T00:00:00Z',
    price: 24.8,
    family_id: 1,
    created_by: 1,
    is_available: true,
    is_featured: false,
    view_count: 98,
    like_count: 65,
    order_count: 32
  }
]

// 模拟数据服务类
export class MockDataService {
  // 获取模拟分类数据
  static getMockCategories(): Category[] {
    return mockCategories
  }

  // 获取模拟菜谱数据
  static getMockRecipes(params?: {
    category_id?: number
    page?: number
    page_size?: number
  }): RecipeListResponse {
    let filteredRecipes = [...mockRecipes]
    
    // 按分类过滤
    if (params?.category_id) {
      filteredRecipes = filteredRecipes.filter(recipe => recipe.category_id === params.category_id)
    }
    
    // 分页处理
    const page = params?.page || 1
    const pageSize = params?.page_size || 10
    const startIndex = (page - 1) * pageSize
    const endIndex = startIndex + pageSize
    const paginatedRecipes = filteredRecipes.slice(startIndex, endIndex)
    
    return {
      recipes: paginatedRecipes,
      total: filteredRecipes.length,
      page,
      page_size: pageSize,
      total_pages: Math.ceil(filteredRecipes.length / pageSize)
    }
  }

  // 添加更多模拟菜谱数据
  static addMoreMockRecipes(): void {
    // 这个方法会在后面扩展更多数据
  }
}
