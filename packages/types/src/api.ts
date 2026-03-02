export type ApiError = {
  error: {
    code: string;
    message: string;
    statusCode: number;
  };
};

export type Pagination = {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
};

export type ApiResponse<T> = {
  data: T;
  pagination?: Pagination;
};
