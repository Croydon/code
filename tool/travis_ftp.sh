#! /bin/bash
#
# upload remote_path local_path [local_paths]...
#
# Upload one or more files to our nightly or dependencies server
# Variables are defined on the Travis website
upload() {
  # Fix an issue where upload directory gets specified by subsequent upload() calls
  ncftpput -R -v -u "$FTP_USER" -p "$FTP_PASSWORD" "$FTP_DOMAIN" / "$@"
}

"$@"  # Call the desired function
