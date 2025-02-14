
# ReviewerTools

The goal of `ReviewerTools` is to provide a set of tools to facilitate
the review process of R / Bioconductor packages. The package is designed
to use a mix of R packages and `system` commands to clone, install,
build, and check packages from the Bioconductor GitHub contributions
repository.

## Installation

You can install the development version of `ReviewerTools` from GitHub
with:

``` r
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

BiocManager::install("Bioconductor/ReviewerTools")
```

## Setup

In order to use the `gh` package, you will need to create a GitHub
personal access token. You can do this by going to your GitHub account
settings, then clicking on “Developer settings” -\> “Personal access
tokens” -\> “Fine-grained Tokens”. You will need to select either “All
repositories” or “Only select repositories” under “Repository Access.”
You can then add the token using:

``` r
library(gitcreds)
gitcreds_set()
```

### Using Bioconductor Docker

We highly recommend using the Bioconductor Docker containers to run the
`ReviewerTools` package. Refer to the [Bioconductor
Docker](https://bioconductor.org/help/docker/) page for more
information. We also recommend using our convenience script to run the
Bioconductor Docker container with the volume mounts for installed
packages. See the GitHub repository
<https://github.com/waldronlab/bioconductor/>. Using the script, one can
run the Bioconductor Docker container with the following:

``` sh
./bioconductor -v devel 
```

Note that the `ReviewerTools` package must be installed separately
within the container.

## Usage

### Package load

``` r
library(ReviewerTools)
```

### Install, build, and check on GitHub issues

The main function in `ReviewerTools` is `check_github_issues`, which
pulls all the reviewer’s issues from the `Bioconductor/contributions`
repository and checks the associated packages. In order to obtain the
issues, the `gh` package is used to interact with the GitHub API. The
function to retrieve the issues is `get_assigned_packages`.

``` r
reviews <- get_assigned_packages("LiNk-NY")
class(reviews)
#> [1] "gh_response" "list"
```

The `check_github_issues` function processes a list of GitHub issues,
cloning the repositories, installing dependencies, building the package,
and checking the package. In this example, we will run
`check_github_issues` on the first assigned review by subsetting the
`reviews` object with a single bracket `[` subset.

``` r
dir.create(tdr <- tempfile())
check_github_issues(reviews[1L], base_repo_dir = tdr, output_dir = tdr)
```

## Inspecting outputs

The `check_github_issues` function will clone the packages in the
`base_repo_dir` and save any outputs to the `output_dir`. For
flexibility, the folder location may be different. One can inspect the
outputs with a text editor or with R via:

``` r
pkgName <- basename(list_assigned_issues(reviews[1L]))
inst_file <- file.path(tdr, paste0(pkgName, "_install.txt"))
readLines(inst_file)
#>  [1] "'getOption(\"repos\")' replaces Bioconductor standard repositories, see"
#>  [2] "'help(\"repositories\", package = \"BiocManager\")' for details."       
#>  [3] "Replacement repositories:"                                              
#>  [4] "    CRAN: https://packagemanager.posit.co/cran/__linux__/jammy/latest"  
#>  [5] "Installing package into ‘/home/mramos/R/bioc-devel’"     
#>  [6] "(as ‘lib’ is unspecified)"                                              
#>  [7] "* installing *source* package 'muSpaData' ..."                          
#>  [8] "** using non-staged installation"                                       
#>  [9] "** R"                                                                   
#> [10] "** inst"                                                                
#> [11] "** byte-compile and prepare package for lazy loading"                   
#> [12] "** help"                                                                
#> [13] "*** installing help indices"                                            
#> [14] "** building package indices"                                            
#> [15] "** installing vignettes"                                                
#> [16] "* DONE (muSpaData)"                                                     
#> [17] "Adding ‘muSpaData_0.99.5_R_x86_64-pc-linux-gnu.tar.gz’ to the cache"
```

## Session Info

<details>
<summary>
Click here to expand
</summary>

``` r
sessionInfo()
#> R Under development (unstable) (2024-11-01 r87285)
#> Platform: x86_64-pc-linux-gnu
#> Running under: Ubuntu 22.04.5 LTS
#> 
#> Matrix products: default
#> BLAS:   /usr/lib/x86_64-linux-gnu/blas/libblas.so.3.10.0 
#> LAPACK: /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.10.0
#> 
#> locale:
#>  [1] LC_CTYPE=en_US.UTF-8       LC_NUMERIC=C              
#>  [3] LC_TIME=en_US.UTF-8        LC_COLLATE=en_US.UTF-8    
#>  [5] LC_MONETARY=en_US.UTF-8    LC_MESSAGES=en_US.UTF-8   
#>  [7] LC_PAPER=en_US.UTF-8       LC_NAME=C                 
#>  [9] LC_ADDRESS=C               LC_TELEPHONE=C            
#> [11] LC_MEASUREMENT=en_US.UTF-8 LC_IDENTIFICATION=C       
#> 
#> time zone: America/New_York
#> tzcode source: system (glibc)
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> other attached packages:
#> [1] ReviewerTools_0.99.0
#> 
#> loaded via a namespace (and not attached):
#>  [1] cli_3.6.3           knitr_1.49          rlang_1.1.5        
#>  [4] xfun_0.50           processx_3.8.5      jsonlite_1.8.9     
#>  [7] gitcreds_0.1.2      glue_1.8.0          openssl_2.3.2      
#> [10] askpass_1.2.1       htmltools_0.5.8.1   BiocBaseUtils_1.9.0
#> [13] ps_1.8.1            sys_3.4.3           rmarkdown_2.29     
#> [16] rappdirs_0.3.3      evaluate_1.0.3      fastmap_1.2.0      
#> [19] yaml_2.3.10         lifecycle_1.0.4     httr2_1.1.0        
#> [22] BiocManager_1.30.25 compiler_4.5.0      codetools_0.2-20   
#> [25] rstudioapi_0.17.1   gh_1.4.1            digest_0.6.37      
#> [28] gert_2.1.4          R6_2.5.1            curl_6.2.0         
#> [31] callr_3.7.6         credentials_2.0.2   magrittr_2.0.3     
#> [34] tools_4.5.0
```

</details>
