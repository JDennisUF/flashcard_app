# 
set -e

flutter build web --release
./fix_base_href.sh
