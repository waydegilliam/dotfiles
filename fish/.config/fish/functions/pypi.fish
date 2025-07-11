function pypi --description 'Check Python packages on PyPI'
    argparse --stop-nonopt v/version h/help -- $argv

    if set -q _flag_version
        echo 'pypi, version 1.0.0'
    else if set -q _flag_help
        _pypi_help
    else if functions --query _pypi_$argv[1]
        _pypi_$argv[1] $argv[2..]
    else
        _pypi_help
        return 1
    end
end

function _pypi_help
    printf %s\n \
        'Usage: pypi [options] subcommand [options]' \
        '' \
        'Options:' \
        '  -v or --version  print pypi version number' \
        '  -h or --help     print this help message' \
        '' \
        'Subcommands:' \
        '  check <package>  check if package exists on PyPI and show info' \
        '  claim [--token <token>] <package>  initialize, build and deploy package to PyPI' \
        '' \
        'Examples:' \
        '  pypi check requests' \
        '  pypi check numpy' \
        '  pypi claim my-package' \
        '  pypi claim --token <pypi-token> my-package'
end

function _pypi_check
    # Check if package name was provided
    if test (count $argv) -eq 0
        echo "Error: Please provide a package name"
        echo "Usage: pypi check <package_name>"
        return 1
    end

    set package_name $argv[1]
    set api_url "https://pypi.org/pypi/$package_name/json"

    # Make the API request
    set response (curl -s -w "HTTPSTATUS:%{http_code}" $api_url)
    set http_code (echo $response | sed -e 's/.*HTTPSTATUS://')
    set json_data (echo $response | sed -e 's/HTTPSTATUS:.*//')

    # Check if the request was successful
    if test $http_code -ne 200
        echo "Error: Package '$package_name' not found on PyPI (HTTP $http_code)"
        return 2
    end

    # Extract package information
    set package_info (echo $json_data | jq -r '.info.name // "N/A"')
    set author (echo $json_data | jq -r '.info.author // "N/A"')
    set author_email (echo $json_data | jq -r '.info.author_email // "N/A"')
    set latest_version (echo $json_data | jq -r '.info.version // "N/A"')
    set summary (echo $json_data | jq -r '.info.summary // "N/A"')
    
    # Get the upload time of the latest release
    set upload_time (echo $json_data | jq -r '.releases["'$latest_version'"][0].upload_time // "N/A"' 2>/dev/null)
    
    # If upload_time is null or empty, try to get it from the last release
    if test "$upload_time" = "N/A" -o "$upload_time" = "null"
        set upload_time (echo $json_data | jq -r '.urls[0].upload_time // "N/A"' 2>/dev/null)
    end

    # Format the upload time if available
    if test "$upload_time" != "N/A" -a "$upload_time" != "null"
        # Convert ISO format to readable date
        set formatted_date (date -d "$upload_time" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null)
        if test $status -eq 0
            set upload_time $formatted_date
        end
    end

    # Display the package information
    echo "Package found on PyPI!"
    echo "======================"
    echo "Name:           $package_info"
    echo "Author:         $author"
    echo "Author Email:   $author_email"
    echo "Latest Version: $latest_version"
    echo "Last Updated:   $upload_time"
    echo "Summary:        $summary"

    return 0
end

function _pypi_claim --description "Initialize, build, and deploy a Python package using uv"
    # Parse arguments
    set -l token ""
    set -l package_name ""
    
    # Process arguments
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --token
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set token $argv[$i]
                else
                    echo "Error: --token requires a value"
                    return 1
                end
            case '*'
                if test -z "$package_name"
                    set package_name $argv[$i]
                else
                    echo "Error: Too many arguments"
                    echo "Usage: pypi claim [--token <token>] <package_name>"
                    return 1
                end
        end
        set i (math $i + 1)
    end
    
    # Check if package name is provided
    if test -z "$package_name"
        echo "Error: Please provide a package name"
        echo "Usage: pypi claim [--token <token>] <package_name>"
        return 1
    end
    
    # Create a temporary directory
    set temp_dir (mktemp -d -t "uv_package_$package_name.XXXXXX")
    
    # Check if temp directory was created successfully
    if test $status -ne 0
        echo "Error: Failed to create temporary directory"
        return 1
    end
    
    # Store the original directory
    set original_dir (pwd)
    
    function __cleanup_temp_dir
        cd $original_dir
        rm -rf $temp_dir
    end
    
    cd $temp_dir
    
    # Initialize the project with uv
    echo "[1/3] Initializing..."
    uv init $package_name >/dev/null 2>&1
    
    if test $status -ne 0
        echo "Error: Failed to initialize project"
        __cleanup_temp_dir
        return 1
    end
    
    # Change into the project directory
    cd $package_name
    
    # Build the package
    echo "[2/3] Building..."
    uv build >/dev/null 2>&1
    
    if test $status -ne 0
        echo "Error: Failed to build package"
        __cleanup_temp_dir
        return 1
    end
    
    # Publish to PyPI
    echo "[3/3] Publishing..."
    
    # Set the token as an environment variable if provided
    if test -n "$token"
        echo "Using provided PyPI token for authentication"
        set publish_output (env UV_PUBLISH_TOKEN=$token uv publish 2>&1)
        set publish_status $status
    else
        echo "No token provided, using default authentication method"
        set publish_output (uv publish 2>&1)
        set publish_status $status
    end
    
    if test $publish_status -ne 0
        echo "Error: Failed to publish package"
        echo "Error details:"
        echo $publish_output
        if test -z "$token"
            echo ""
            echo "Make sure you have PyPI credentials configured or provide a token with --token"
        end
        __cleanup_temp_dir
        return 1
    end
    
    # Success message
    echo "Successfully initialized, built, and published '$package_name' to PyPI!"
    
    # Clean up
    __cleanup_temp_dir
    
    return 0
end

