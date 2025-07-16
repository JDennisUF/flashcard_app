# 
set -e

flutter build web --release
./fix_base_href.sh
./update_web_repo.sh
