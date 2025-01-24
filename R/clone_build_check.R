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

            # Set working directory to repository
            setwd(repo_path)

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

# Helper function to extract repository URL from issue body
extract_repo_url <- function(body) {
    # Regular expression to find GitHub repository URLs
    url_pattern <- "https://github\\.com/[a-zA-Z0-9-]+/[a-zA-Z0-9-]+"
    urls <- regmatches(body, gregexpr(url_pattern, body))[[1]]

    if (length(urls) > 0) {
        return(urls[1])  # Return first repository URL found
    }

    return(NULL)
}
