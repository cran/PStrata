#' Create a Principal Stratification Object
#' 
#' Create an object containing essential information to create the Stan file and 
#' data for Stan to draw posterior samples. Such information includes the specified
#' model for principal stratum and outcome, the type of outcome, assumptions,
#' and prior specification, etc.
#' 
#' 
#' @param S.formula,Y.formula an object of class "\code{\link{PSFormula}}" (or an
#' object of class "\code{\link{formula}}" that can be coerced to
#' that class with \code{data} provided) specifying the model for principal
#' stratum and outcome respectively. See \code{\link{PSFormula}} for details.
#' @param Y.family an object of class "\code{\link{family}}": specifying the parametric
#' family of the model for the response and the link function. See the documentation
#' for \code{\link{glm}} for details on how such model fitting takes place.
#' Supported families and corresponding link functions are presented in 'Details' below. 
#' @param data (optional) a data frame object. This is required when either 
#' \code{S.formula} or \code{Y.formula} is a \code{formula} object, to coerce
#' it into a \code{PSFormula} object. When this happens, the data frame should 
#' contain all of the variables with names given in \code{S.formula} or \code{Y.formula}.
#' @param strata,ER arguments to define the principal strata. See \code{\link{PStrataInfo}} for details.
#' 
#' Alternatively, one can pass an object of class \code{PStrataInfo} to \code{strata},
#' and \code{ER} will be ignored.
#' @param prior_intercept,prior_coefficient,prior_sigma,prior_alpha,prior_lambda,prior_theta
#' prior distribution for corresponding parameters in the model. 
#' @param survival.time.points a vector of time points at which the estimated survival probability is evaluated 
#' (only used when the type of outcome is survival), or an integer specifying the number of time points to be
#' chosen. By default, the time points are chosen with equal distance from 0 to the 90\% quantile of the observed
#' outcome.
#' @return A list, containing important information describing the principal stratification model.
#' \item{S.formula, Y.formula}{A \code{PSFormula} object converted from the input \code{S.formula} and \code{Y.formula}}
#' \item{Y.family}{Same as input.}
#' \item{is.survival}{A boolean value. \code{TRUE} if \code{Y.family} is \code{survival_Cox} or \code{survival_AFT}.}
#' \item{strata_info}{A \code{PStrataInfo} object converted from the input \code{strata} and \code{ER}.}
#' \item{prior_intercept, prior_coefficient, prior_sigma, prior_alpha, prior_lambda, prior_theta}{Same as input.}
#' \item{survival.time.points}{A list of time points at which the estimated survival probability is evaluated.}
#' \item{SZDG_table}{A matrix. Each row corresponds to a valid (stratum, treatment, confounder, group) combination.}
#' \item{Z_names}{A character vector. The names of the levels of the treatment.}
#' 
#' @details 
#' The supported \code{family} objects include two types: native families for ordinary outcome and 
#' \code{survival} family for survival outcome.
#' 
#' For ordinary outcome, the below families and links are supported. See \code{\link{family}} for more details.
#' \tabular{ll}{
#'  \bold{family} \tab \bold{link} \cr
#'  \code{binomial} \tab \code{logit}, \code{probit}, \code{cauchit}, \code{log}, \code{cloglog} \cr
#'  \code{gaussian} \tab \code{identity}, \code{log}, \code{inverse} \cr
#'  \code{Gamma} \tab \code{inverse}, \code{identity}, \code{log} \cr
#'  \code{poisson} \tab \code{log}, \code{identity}, \code{log} \cr
#'  \code{inverse.gamma} \tab \code{1/mu^2}, \code{inverse}, \code{identity}, \code{log} 
#' }
#' The \code{quasi} family is not supported for the current version of the package.
#'
#' For survival outcome, the \code{family} object is created by 
#' \code{survival(method = "Cox", link = "identity")}, where \code{method} can be
#' either \code{"Cox"} for Weibull-Cox model or \code{"AFT"} for accelerated 
#' failure time model. See \code{\link{survival}} for more details. For the current
#' version, only \code{"identity"} is used as the link function.
#' 
#' The \code{gaussian} family and the \code{survival} family with \code{method = "AFT"}
#' introduce an additional parameter \code{sigma} for the standard deviation, whose 
#' prior distribution is specified by \code{prior_sigma}. Similarly, \code{prior_alpha}
#' specifies the prior distribution of \code{alpha} for \code{Gamma} family, 
#' \code{prior_lambda} specifies the prior distribution of \code{theta} for \code{inverse.gaussian} family, 
#' and \code{prior_theta}
#' specifies the prior distribution of \code{theta} for \code{survival} family with \code{method = "Cox"}.
#' 
#' The models for principal stratum \code{S.formula} and response \code{Y.formula}
#' also involve a linear combination of terms, where the prior distribution of
#' the intercept and coefficients are specified by \code{prior_intercept} and 
#' \code{prior_coefficient} respectively.
#' 
#' @examples
#' df <- data.frame(
#'   Z = rbinom(10, 1, 0.5),
#'   D = rbinom(10, 1, 0.5),
#'   Y = rnorm(10),
#'   X = 1:10
#' )
#' 
#' PSObject(
#'   S.formula = Z + D ~ X,
#'   Y.formula = Y ~ X,
#'   Y.family = gaussian("identity"),
#'   data = df,
#'   strata = c(n = "00*", c = "01", a = "11*")
#' )
#' 
#' #------------------------------
#' 
#' PSObject(
#'   S.formula = Z + D ~ 1,
#'   Y.formula = Y ~ 1,
#'   Y.family = gaussian("identity"),
#'   data = sim_data_normal,
#'   strata = c(n = "00*", c = "01", a = "11*")
#' )
#' 
#' @export
PSObject <- function(
  S.formula, Y.formula, Y.family, 
  data = NULL, 
  strata = NULL, 
  ER = NULL,
  prior_intercept = prior_flat(),
  prior_coefficient = prior_normal(),
  prior_sigma = prior_inv_gamma(),
  prior_alpha = prior_inv_gamma(),
  prior_lambda = prior_inv_gamma(),
  prior_theta = prior_normal(),
  survival.time.points = 50
) {
  if (!inherits(S.formula, "PSFormula")) {
    S.formula <- PSFormula(S.formula, data)
  }
  if (!inherits(Y.formula, "PSFormula")) {
    Y.formula <- PSFormula(Y.formula, data)
  }
  if (!inherits(strata, "PStrataInfo")) {
    strata <- PStrataInfo(strata, ER)
  }
  
  Z <- dplyr::pull(S.formula$data, S.formula$response_names[1])
  if (is.factor(Z)) {
    Z_int <- as.integer(Z)
    Z_levels <- levels(Z)
  } else if (all(sapply(Z, function(x) x %in% 0:(strata$num_treatment - 1)))) {
    Z_int <- Z
    Z_levels <- 0:(strata$num_treatment - 1)
  } else {
    warning("The treatment variable does not start from 0 or is not a factor. \n
            Unexpected issues might occur by determining the treatment levels automatically.\n")
    Z <- as.factor(Z)
    Z_int <- as.integer(Z)
    Z_levels <- levels(Z)
  }
  
  SZDG <- matrix(nrow = 0, ncol = 4)
  colnames(SZDG) <- c("S", "Z", "D", "G")
  G_id <- 0
  
  for (strata_id in 1:strata$num_strata) {
    S_id <- strata_id - 1
    for (treatment_id in 1:strata$num_treatment) {
      Z_id <- treatment_id - 1
      D_id <- strata$strata_matrix[strata_id, treatment_id]
      tmp_G_id <- NULL
      if (strata$ER_list[strata_id] && nrow(SZDG) > 0) {
        for (i in 1:nrow(SZDG)) {
          if (SZDG[i, 1] == S_id && SZDG[i, 3] == D_id) {
            tmp_G_id <- SZDG[i, 4]
          }
        }
      }
      if (is.null(tmp_G_id)) {
        G_id <- G_id + 1
        tmp_G_id <- G_id
      }
      SZDG <- rbind(SZDG, c(S_id, Z_id, D_id, tmp_G_id))
    }
  }
  return (structure(
    list(
      S.formula = S.formula,
      Y.formula = Y.formula,
      Y.family = Y.family,
      is.survival = Y.family$family %in% c("survival_Cox", "survival_AFT"),
      strata_info = strata,
      prior_intercept = prior_intercept,
      prior_coefficient = prior_coefficient,
      prior_sigma = prior_sigma,
      prior_alpha = prior_alpha,
      prior_lambda = prior_lambda,
      prior_theta = prior_theta,
      survival.time.points = survival.time.points,
      SZDG_table = SZDG,
      Z_names = Z_levels
    )
  ))
}
