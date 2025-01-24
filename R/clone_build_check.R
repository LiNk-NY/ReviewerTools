#' @examples
#' reviews <- get_assigned_packages("LiNk-NY")
#' check_github_issues(reviews)
#' @export
get_assigned_packages <- function(
    username,  org = "Bioconductor",  repo = "contributions"
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

#'
#' @export
check_github_issues <- function(issues, base_repo_dir = ".") {
    # Process each issue
    for (issue in issues) {
        # Set working directory to repository
        oldwd <- setwd(base_repo_dir)
        # Extract repository information from issue body
        repo_url <- extract_repo_url(issue$body)

        if (!is.null(repo_url)) {
            # Define paths
            repo_name <- basename(repo_url)
            repo_path <- file.path(base_repo_dir, repo_name)

            # Clone or update repository
            if (!dir.exists(repo_path)) {
                gert::git_clone(repo_url, path = repo_path)
            } else {
                gert::git_pull(repo = repo_path)
            }

            # Prepare output file paths
            build_log <- file.path(
                base_repo_dir, paste0(repo_name, "_build.txt")
            )
            check_log <- file.path(
                base_repo_dir, paste0(repo_name, "_check.txt")
            )

            # Install dependencies and check package
            tryCatch({
                # Capture install output
                sink(
                    file.path(base_repo_dir, paste0(repo_name, "_install.txt"))
                )
                remotes::install_local(
                    repos = BiocManager::repositories(), dependencies = TRUE
                )
                sink()

                # Build package with output log
                system(paste0("R CMD build . > ", build_log, " 2>&1"))

                # Check package with output log
                system(paste0("R CMD check *.tar.gz > ", check_log, " 2>&1"))
            }, error = function(e) {
                message("Error processing repository: ", repo_url)
                print(e)
            })
        }
        setwd(oldwd)
    }
}

# extract repository URLs from body and comments
extract_repo_urls <- function(
    body, org = "Bioconductor", repo = "contributions", issue_number = NULL
) {
    # Regular expression to find GitHub repository URLs
    url_pattern <- "https://github\\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+"
    additional_package_pattern <-
        "AdditionalPackage: (https://github\\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+)"

    # Extract URLs from body
    body_urls <- regmatches(body, gregexpr(url_pattern, body))[[1]]

    # Extract URLs from comments if issue_number is provided
    comment_urls <- c()
    if (!is.null(issue_number)) {
        comments <- gh::gh(
            "/repos/{owner}/{repo}/issues/{issue_number}/comments",
            owner = repo_owner,
            repo = repo_name,
            issue_number = issue_number
        )

        for (comment in comments) {
            # Look for AdditionalPackage: URLs
            urls <- regmatches(
                comment$body,
                gregexpr(additional_package_pattern, comment$body, perl = TRUE)
            )
            if (length(urls[[1]]) > 0) {
                # Extract the actual URL
                extracted_urls <- gsub("AdditionalPackage: ", "", urls[[1]])
                comment_urls <- c(comment_urls, extracted_urls)
            }
        }
    }

    # Combine and return unique URLs
    return(unique(c(body_urls, comment_urls)))
}
