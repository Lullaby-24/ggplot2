#' @rdname geom_boxplot
#' @param coef Length of the whiskers as multiple of IQR. Defaults to 1.5.
#' @inheritParams stat_identity
#' @section Computed variables:
#' \describe{
#'   \item{width}{width of boxplot}
#'   \item{ymin}{lower whisker = smallest observation greater than or equal to lower hinge - 1.5 * IQR}
#'   \item{lower}{lower hinge, 25\% quantile}
#'   \item{notchlower}{lower edge of notch = median - 1.58 * IQR / sqrt(n)}
#'   \item{middle}{median, 50\% quantile}
#'   \item{notchupper}{upper edge of notch = median + 1.58 * IQR / sqrt(n)}
#'   \item{upper}{upper hinge, 75\% quantile}
#'   \item{ymax}{upper whisker = largest observation less than or equal to upper hinge + 1.5 * IQR}
#' }
#' @export
stat_boxplot <- function(mapping = NULL, data = NULL,
                         geom = "boxplot", position = "dodge2",
                         ...,
                         coef = 1.5,
                         na.rm = FALSE,
                         orientation = NA,
                         show.legend = NA,
                         inherit.aes = TRUE) {
  layer(
    data = data,
    mapping = mapping,
    stat = StatBoxplot,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(
      na.rm = na.rm,
      orientation = orientation,
      coef = coef,
      ...
    )
  )
}


#' @rdname ggplot2-ggproto
#' @format NULL
#' @usage NULL
#' @export
StatBoxplot <- ggproto("StatBoxplot", Stat,
  required_aes = c("y|x"),
  non_missing_aes = "weight",
  setup_data = function(data, params) {
    data <- flip_data(data, params$flipped_aes)
    data$x <- data$x %||% 0
    data <- remove_missing(
      data,
      na.rm = params$na.rm,
      vars = "x",
      name = "stat_boxplot"
    )
    flip_data(data, params$flipped_aes)
  },

  setup_params = function(data, params) {
    params$flipped_aes <- has_flipped_aes(data, params, main_is_orthogonal = TRUE, group_has_equal = TRUE)
    data <- flip_data(data, params$flipped_aes)

    has_x <- !(is.null(data$x) && is.null(params$x))
    has_y <- !(is.null(data$y) && is.null(params$y))
    if (!has_x && !has_y) {
      stop("stat_boxplot() requires an x or y aesthetic.", call. = FALSE)
    }

    params$width <- params$width %||% (resolution(data$x %||% 0) * 0.75)

    if (is.double(data$x) && !has_groups(data) && any(data$x != data$x[1L])) {
      warning(
        "Continuous ", flipped_names(params$flipped_aes)$x, " aesthetic -- did you forget aes(group=...)?",
        call. = FALSE)
    }

    params
  },

  extra_params = c("na.rm", "orientation"),

  compute_group = function(data, scales, width = NULL, na.rm = FALSE, coef = 1.5, flipped_aes = FALSE) {
    data <- flip_data(data, flipped_aes)
    qs <- c(0, 0.25, 0.5, 0.75, 1)

    if (!is.null(data$weight)) {
      mod <- quantreg::rq(y ~ 1, weights = weight, data = data, tau = qs)
      stats <- as.numeric(stats::coef(mod))
    } else {
      stats <- as.numeric(stats::quantile(data$y, qs))
    }
    names(stats) <- c("ymin", "lower", "middle", "upper", "ymax")
    iqr <- diff(stats[c(2, 4)])

    outliers <- data$y < (stats[2] - coef * iqr) | data$y > (stats[4] + coef * iqr)
    if (any(outliers)) {
      stats[c(1, 5)] <- range(c(stats[2:4], data$y[!outliers]), na.rm = TRUE)
    }

    if (length(unique(data$x)) > 1)
      width <- diff(range(data$x)) * 0.9

    df <- new_data_frame(as.list(stats))
    df$outliers <- list(data$y[outliers])

    if (is.null(data$weight)) {
      n <- sum(!is.na(data$y))
    } else {
      # Sum up weights for non-NA positions of y and weight
      n <- sum(data$weight[!is.na(data$y) & !is.na(data$weight)])
    }

    df$notchupper <- df$middle + 1.58 * iqr / sqrt(n)
    df$notchlower <- df$middle - 1.58 * iqr / sqrt(n)

    df$x <- if (is.factor(data$x)) data$x[1] else mean(range(data$x))
    df$width <- width
    df$relvarwidth <- sqrt(n)
    df$flipped_aes <- flipped_aes
    flip_data(df, flipped_aes)
  }
)
