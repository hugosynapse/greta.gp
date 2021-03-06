# tensorflow implementations of common kernels

# bias (or constant) kernel
# k(x, y) = \sigma^2
tf_bias <- function(X, X_prime, variance, active_dims) {
  
    # calculate dims from X and X_prime
    dims_out <- tf$stack(c(tf$shape(X)[0L], tf$shape(X)[1L], tf$shape(X_prime)[1L]))
  
    # create and return covariance matrix
    tf$fill(dims_out, tf$squeeze(variance))

}

# white kernel 
# diagonal with specified variance if self-kernel, all 0s otherwise
tf_white <- function(X, X_prime, variance, active_dims) {
  
  # only non-zero for self-covariance matrices
  if (identical(X, X_prime)) {
    # construct variance array and convert to diagonal array with batch dims
    d <- tf$fill(tf$stack(c(tf$shape(X)[0L], tf$shape(X)[1L])), tf$squeeze(variance))
    d <- tf$matrix_diag(d)
  } else {
    d <- tf$zeros(tf$stack(c(tf$shape(X)[0L], tf$shape(X)[1L], tf$shape(X_prime)[1L])),
                  dtype = options()$greta_tf_float)
  }
  
  # return constructed covariance matrix
  d
    
}

# squared exponential kernel (RBF)
tf_rbf <- function(X, X_prime, lengthscales, variance, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)

  # calculate squared distances
  r2 <- squared_dist(X, X_prime, lengthscales)
  
  # construct and return RBF kernel
  variance * tf$exp(-r2 / tf$constant(2.0, dtype = options()$greta_tf_float))
  
}

# rational_quadratic kernel
tf_rational_quadratic <- function(X, X_prime, lengthscales, variance, alpha, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)
  
  # calculate squared distances (scaled if needed)
  r2 <- squared_dist(X, X_prime, lengthscales)

  # construct and return rational quadratic kernel
  variance * (tf$constant(1., dtype = options()$greta_tf_float) +
                r2 / (tf$constant(2., dtype = options()$greta_tf_float) * alpha)) ^ -alpha

}

# linear kernel (base class)
tf_linear <- function(X, X_prime, variances, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)

  # full kernel
  tf$matmul(tf$multiply(variances, X), X_prime, transpose_b = TRUE)

}

tf_polynomial <- function(X, X_prime, variances, offset, degree, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)

  # full kernel  
  tf$pow(tf$matmul(tf$multiply(variances, X), X_prime, transpose_b = TRUE) + offset, degree)
  
}

# # exponential kernel (stationary class)
tf_exponential <- function(X, X_prime, lengthscales, variance, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)
  
  # calculate squared distances (scaled if needed)
  r <- absolute_dist(X, X_prime, lengthscales)

  # construct and return exponential kernel
  variance * tf$exp(-tf$constant(0.5, dtype = options()$greta_tf_float) * r)

}

# Matern12 kernel (stationary class)
tf_Matern12 <- function(X, X_prime, lengthscales, variance, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)
  
  # calculate squared distances (scaled if needed)
  r <- absolute_dist(X, X_prime, lengthscales)

  # construct and return Matern12 kernel
  variance * tf$exp(-r)

}

# Matern32 kernel (stationary class)
tf_Matern32 <- function(X, X_prime, lengthscales, variance, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)
  
  # calculate squared distances (scaled if needed)
  r <- absolute_dist(X, X_prime, lengthscales)

  # precalculate root3
  sqrt3 <- sqrt(tf$constant(3.0, dtype = options()$greta_tf_float))

  # construct and return Matern32 kernel
  variance * (tf$constant(1.0, dtype = options()$greta_tf_float) + sqrt3 * r) * tf$exp(-sqrt3 * r)

}

# Matern52 kernel (stationary class)
tf_Matern52 <- function(X, X_prime, lengthscales, variance, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)
  
  # calculate squared distances (scaled if needed)
  r <- absolute_dist(X, X_prime, lengthscales)
  
  # precalculate root5
  sqrt5 <- sqrt(tf$constant(5.0, dtype = options()$greta_tf_float))

  # construct and return Matern52 kernel
  variance * (tf$constant(1.0, dtype = options()$greta_tf_float) +
                sqrt5 * r + tf$constant(5.0, dtype = options()$greta_tf_float) / 
                tf$constant(3.0, dtype = options()$greta_tf_float) * tf$square(r)) * tf$exp(-sqrt5 * r)

}

# cosine kernel (stationary class)
tf_cosine <- function(X, X_prime, lengthscales, variance, active_dims) {

  # pull out active dimensions
  X <- tf_slice(X, active_dims)
  X_prime <- tf_slice(X_prime, active_dims)
  
  # calculate squared distances (scaled if needed)
  r <- absolute_dist(X, X_prime, lengthscales)

  # construct and return cosine kernel
  variance * tf$cos(r)

}

# periodic kernel
tf_periodic <- function(X, X_prime, lengthscale, variance, period) {

  # calculate squared distances (scaled if needed)
  exp_arg <- tf$constant(pi, dtype = options()$greta_tf_float) * absolute_dist(X, X_prime) / period
  exp_arg <- sin(exp_arg) / lengthscale

  # construct and return periodic kernel
  variance * tf$exp(-tf$constant(0.5, dtype = options()$greta_tf_float) *
                      exp_arg ^ tf$constant(2., dtype = options()$greta_tf_float))
  
}

tf_Prod <- function(kernel_a, kernel_b) {
  
  tf$multiply(kernel_a, kernel_b)
  
}

tf_Add <- function(kernel_a, kernel_b) {
  
  tf$add(kernel_a, kernel_b)

}

# rescale, calculate, and return clipped squared distance
squared_dist <- function(X, X_prime, lengthscales = NULL) {
  
  if (!is.null(lengthscales)) {
    X <- X / lengthscales
    X_prime <- X_prime / lengthscales
  }

  Xs <- tf$reduce_sum(tf$square(X), axis = -1L)
  Xs_prime <- tf$reduce_sum(tf$square(X_prime), axis = -1L)
  
  dist <- tf$constant(-2.0, dtype = tf$float64) * tf$matmul(X, X_prime, transpose_b = TRUE)  
  dist <- dist + tf$expand_dims(Xs, -1L)
  dist <- dist + tf$expand_dims(Xs_prime, -2L)
  
  # return value clipped around single float precision
  tf$maximum(dist, 1e-40)
  
}

# rescale, calculate, and return clipped squared distance
absolute_dist <- function(X, X_prime, lengthscales = NULL) {
  
  if (!is.null(lengthscales)) {
    X <- X / lengthscales
    X_prime <- X_prime / lengthscales
  }
  
  Xs <- tf$reduce_sum(tf$square(X), axis = -1L)
  Xs_prime <- tf$reduce_sum(tf$square(X_prime), axis = -1L)
  
  dist <- tf$constant(-2., dtype = options()$greta_tf_float) * tf$matmul(X, X_prime, transpose_b = TRUE)  
  dist <- dist + tf$expand_dims(Xs, -1L)
  dist <- dist + tf$expand_dims(Xs_prime, -2L)
  
  # return value clipped around single float precision
  tf$sqrt(tf$maximum(dist, 1e-40))
  
}

# helper function to pull out slices of tensors and add final dim if dropped
tf_slice <- function(X, dims) {
  
  X <- tf$gather_nd(X, dims, axis = -1L)
  
  if (length(dims) == 1)
    X <- tf$expand_dims(X, axis = -1L)
  
  X
  
}

# combine as module for export via internals
# tf_kernels_module <- module(tf_static,
#                             tf_constant,
#                             tf_bias,
#                             tf_squared_exponential,
#                             tf_rational_quadratic,
#                             tf_linear,
#                             tf_polynomial,
#                             tf_exponential,
#                             tf_Matern12,
#                             tf_Matern32,
#                             tf_Matern52,
#                             tf_cosine)
