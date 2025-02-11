#' @examples
#' reviews <- get_assigned_packages("LiNk-NY")
#' list_assigned_issues(reviews)
#' ## pull any additional packages
#' get_additional_packages(reviews[[2L]])
#' check_github_issues(reviews, base_repo_dir = "~/reviews")
#' @export
get_assigned_packages <- function(
    username, org = "Bioconductor", repo = "contributions"
) {
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

#' @export
list_assigned_issues <- function(issues) {
    vapply(
        issues, function(issue) extract_repo_urls(issue$body), character(1L)
    )
}

#' @export
check_github_issues <- function(issues, base_repo_dir = ".") {
    # Process each issue
    for (issue in issues) {
        # Set working directory to repository
        oldwd <- setwd(base_repo_dir)

        issue_number <- basename(issue$url)
        # Extract repository information from issue body
        repo_url <- extract_repo_urls(issue$body)

        .install_build_check(repo_url)
        setwd(oldwd)
    }
}

.install_build_check <- function(repo_url, base_repo_dir = ".") {
    stopifnot(
        isScalarCharacter(repo_url), isScalarCharacter(base_repo_dir)
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
        base_repo_dir, paste0(repo_name, "_install.txt")
    )
    build_log <- file.path(
        base_repo_dir, paste0(repo_name, "_build.txt")
    )
    check_log <- file.path(
        base_repo_dir, paste0(repo_name, "_check.txt")
    )

    # Install dependencies and check package
    tryCatch({
        # Capture install output
        message("Working on ", repo_name, ":")
        sink(install_log)
        remotes::install_local(
            path = repo_name,
            repos = BiocManager::repositories(),
            dependencies = TRUE,
            upgrade = "never"
        )
        sink()

        # Build package with output log
        sink(build_log)
        devtools::build(
            pkg = repo_name, vignettes = FALSE
        )
        sink()

        # Check package with output log
        sink(check_log)
        rcmdcheck::rcmdcheck(
            path = repo_name,
            build_args = "--no-build-vignettes",
            args = c("--no-manual", "--no-vignettes"),
        )
        sink()
    }, error = function(e) {
        message("Error processing repository: ", repo_url)
        print(e)
    })
}

#' @examples
#' clone_check_github("3039", base_repo_dir = "~/reviews")
#'
#' @importFrom BiocBaseUtils isScalarCharacter
#'
#' @export
clone_check_github <- function(
    issue_number, org = "Bioconductor", repo = "contributions",
    base_repo_dir = "."
) {
    issue <- gh::gh(
        "/repos/{owner}/{repo}/issues/{issue_number}",
        owner = org,
        repo = repo,
        issue_number = issue_number
    )

    oldwd <- setwd(base_repo_dir)

    repo_url <- extract_repo_urls(issue$body)

    .install_build_check(repo_url)

    setwd(oldwd)
}

#' @export
extract_repo_urls <- function(body) {
    # Regular expression to find GitHub repository URLs
    url_pattern <- "https://github\\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+"

    # Extract URLs from body
    regmatches(body, gregexpr(url_pattern, body))[[1]]
}

#' @export
get_additional_packages <- function(
    issue, org = "Bioconductor", repo = "contributions", issue_number = NULL
) {
    stopifnot(all(c("url", "body") %in% names(issue)))
    # Extract URLs from body
    body_urls <- extract_repo_urls(issue$body)
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
