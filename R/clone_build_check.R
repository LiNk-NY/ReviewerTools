#' @name check_github_issues
#'
#' @title Clone, build, and check Bioconductor contributions directly from
#'   GitHub
#'
#' @description The functions are designed to be used with the GitHub API and
#'   the `gh` package. The typical workflow is to fetch issues assigned to a
#'   specific Bioconductor reviewer. The reviewer can then extract the
#'   repository URLs from the issue body and clone, install dependencies, build,
#'   and check the package.
#'
#' @details
#' * `check_github_issues`, processes a list of GitHub
#'   issues, cloning the repositories, installing dependencies, building the
#'   package, and checking the package.
#'
#' * `get_assigned_packages` fetches issues assigned to a specific GitHub
#'   username (reviewer).
#'
#' * `list_assigned_issues` extracts repository URLs from the issue bodies.
#'
#' * `clone_check_github` clones, installs dependencies, builds, and checks a
#'   single GitHub repository with the issue number as input.
#'
#' * `get_additional_packages` extracts additional repository URLs from the
#'   `AdditionalPackage` comment within an issue.
#'
#' @param issues `gh_response` / `list` GitHub issues obtained by
#'   `get_assigned_packages`
#'
#' @param base_repo_dir `character(1)` The base directory where the repositories
#'   will be cloned to. Default is the current working directory.
#'
#' @param output_dir `character(1)` The directory where the output files will be
#'   saved. Default is the current working directory.
#'
#' @param username `character(1)` The GitHub username of the reviewer.
#'
#' @param org `character(1)` The GitHub organization. Default is "Bioconductor".
#'
#' @param repo `character(1)` The GitHub repository of the issue tracker (by
#'   default "contributions").
#'
#' @importFrom BiocBaseUtils isScalarCharacter
#'
#' @examples
#' reviews <- get_assigned_packages("LiNk-NY")
#' check_github_issues(reviews, base_repo_dir = "~/reviews")
#' @export
check_github_issues <- function(issues, base_repo_dir = ".", output_dir = ".") {
    stopifnot(
        inherits(issues, "gh_response") || is.list(issues),
        isScalarCharacter(base_repo_dir)
    )
    # Process each issue
    for (issue in issues) {
        # Set working directory to repository
        oldwd <- setwd(base_repo_dir)

        issue_number <- basename(issue$url)
        # Extract repository information from issue body
        repo_url <- .extract_repo_urls(issue$body)

        .install_build_check(
            repo_url, base_repo_dir = base_repo_dir, output_dir = output_dir
        )
        setwd(oldwd)
    }
}

#' @rdname check_github_issues
#' @export
get_assigned_packages <- function(
    username, org = "Bioconductor", repo = "contributions"
) {
    stopifnot(
        isScalarCharacter(username),
        isScalarCharacter(org), isScalarCharacter(repo)
    )
    if (missing(username))
        stop("Please provide a GitHub username.")
    # Fetch issues assigned to the specified username
    gh::gh(
        "/repos/:owner/:repo/issues",
        owner = org,
        repo = repo,
        assignee = username,
        state = "open"
    )
}

#' @rdname check_github_issues
#' @examples
#' list_assigned_issues(reviews)
#'
#' @export
list_assigned_issues <- function(issues) {
    stopifnot(inherits(issues, "gh_response") || is.list(issues))
    vapply(
        issues, function(issue) .extract_repo_urls(issue$body), character(1L)
    )
}

.install_build_check <- function(repo_url, base_repo_dir, output_dir) {
    stopifnot(
        isScalarCharacter(repo_url), isScalarCharacter(base_repo_dir),
        isScalarCharacter(output_dir)
    )
    # Define paths
    repo_name <- basename(repo_url)
    repo_path <- file.path(base_repo_dir, repo_name)

    # Clone or update repository
    if (!dir.exists(repo_path)) {
        gert::git_clone(repo_url, path = repo_path)
    } else {
        gert::git_pull(repo = repo_name)
    }

    # Prepare output file paths
    install_log <- file.path(
        output_dir, paste0(repo_name, "_install.txt")
    )
    build_log <- file.path(
        output_dir, paste0(repo_name, "_build.txt")
    )
    check_log <- file.path(
        output_dir, paste0(repo_name, "_check.txt")
    )

    # Install dependencies and check package
    tryCatch({
        # Capture install output
        install_fun <- function(repo_name) {
            remotes::install_local(
                path = repo_name,
                dependencies = TRUE,
                upgrade = "never",
                repos = BiocManager::repositories(),
                force = TRUE,
                build = FALSE,
                INSTALL_opts = c(
                    "--no-test-load", "--no-staged-install",
                    "--no-multiarch", "--with-keep.source"
                )
            )
        }
        callr::r_safe(
            install_fun,
            args = list(repo_name),
            stdout = install_log,
            stderr = install_log
        )
        # Build package with output log
        system(
            paste0(
                R.home("bin"), .Platform$file.sep,  "R",
                " CMD build --no-manual --no-build-vignettes ",
                repo_name, " > ", build_log, " 2>&1"
            )
        )
        # Check package with output log
        system(
            paste0(
                R.home("bin"), .Platform$file.sep,  "R",
                " CMD check --no-vignettes ",
                repo_name, "*.tar.gz > ", check_log, " 2>&1"
            )
        )
    }, error = function(e) {
        message("Error processing repository: ", repo_url)
        print(e)
    })
}

#' @rdname check_github_issues
#' @examples
#' clone_check_github("3039", base_repo_dir = "~/reviews")
#'
#' @export
clone_check_github <- function(
    issue_number, org = "Bioconductor", repo = "contributions",
    base_repo_dir = ".", output_dir = "."
) {
    issue <- gh::gh(
        "/repos/{owner}/{repo}/issues/{issue_number}",
        owner = org,
        repo = repo,
        issue_number = issue_number
    )

    oldwd <- setwd(base_repo_dir)

    repo_url <- .extract_repo_urls(issue$body)

    .install_build_check(
        repo_url, base_repo_dir = base_repo_dir, output_dir = output_dir
    )

    setwd(oldwd)
}

.extract_repo_urls <- function(body) {
    # Regular expression to find GitHub repository URLs
    url_pattern <- "https://github\\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+"

    # Extract URLs from body
    regmatches(body, gregexpr(url_pattern, body))[[1]]
}

#' @rdname check_github_issues
#' @examplesIf interactive()
#' ## pull any additional packages
#' get_additional_packages(reviews[[2L]])
#'
#' @export
get_additional_packages <- function(
    issue, org = "Bioconductor", repo = "contributions", issue_number = NULL
) {
    stopifnot(all(c("url", "body") %in% names(issue)))
    # Extract URLs from body
    body_urls <- .extract_repo_urls(issue$body)
    issue_number <- basename(issue$url)

    additional_package_pattern <-
        "AdditionalPackage: (https://github\\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+)"

    # Extract URLs from comments if issue_number is provided
    comment_urls <- c()
    comments <- gh::gh(
        "/repos/{owner}/{repo}/issues/{issue_number}/comments",
        owner = org,
        repo = repo,
        issue_number = issue_number
    )

    for (comment in comments) {
        # Look for AdditionalPackage: URLs
        urls <- regmatches(
            comment$body,
            gregexpr(additional_package_pattern, comment$body, perl = TRUE)
        )
        if (length(urls[[1L]])) {
            # Extract the actual URL
            extracted_urls <- gsub("AdditionalPackage: ", "", urls[[1]])
            comment_urls <- c(comment_urls, extracted_urls)
        }
    }

    # Combine and return unique URLs
    unique(c(body_urls, comment_urls))
}
