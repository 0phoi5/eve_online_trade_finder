#!/usr/bin/env bash
set -euo pipefail

# Usage: ./grab_buy_orders.sh input.csv
# input.csv header: item_id,item_name,...

INPUT_CSV="${1:-input.csv}"
ESI="https://esi.evetech.net/latest"
DS="tranquility"
VERBOSE="${VERBOSE:-1}"   # set VERBOSE=0 to quiet

command -v jq >/dev/null || { echo "Install jq: sudo apt-get install -y jq"; exit 1; }

# Exact in-game names for the 5 trade hubs
HUBS=(
  "Jita IV - Moon 4 - Caldari Navy Assembly Plant"
  "Amarr VIII (Oris) - Emperor Family Academy"
  "Dodixie IX - Moon 20 - Federation Navy Assembly Plant"
  "Rens VI - Moon 8 - Brutor Tribe Treasury"
  "Hek VIII - Moon 12 - Boundless Creation Factory"
  "Onnamon VII – Caldari Navy Anchorage"
  "Stacmon V - Moon 9 - Federation Navy Assembly Plant"
  "Hodrold VII - Moon 8 - Thukker Mix"
  "Torrinos V - Moon 5 - Lai Dai Corporation Factory"
  "Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"
  "Paye VI - Moon 1 - Imperial Academy"
  "Oursulaert III - Federation Navy Testing Facilities"
  "Tash-Murkon Prime II - Moon 1 - Kaalakiota Corporation Factory"
  "Agil VI - Moon 2 - CONCORD"
  "Perimeter - Tranquility Trading Tower"
  "Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"
  "Nourvukaiken V - State Protectorate Logistic Support"
  "Sobaseki VII - Caldari Navy Logistic Support"
  "Lustrevik VII - Moon 9 - Brutor Tribe Academy"
)

# Known NPC station IDs
declare -A HUB_STATION_ID=(
  ["Jita IV - Moon 4 - Caldari Navy Assembly Plant"]="60003760"
  ["Amarr VIII (Oris) - Emperor Family Academy"]="60008494"
  ["Dodixie IX - Moon 20 - Federation Navy Assembly Plant"]="60011866"
  ["Rens VI - Moon 8 - Brutor Tribe Treasury"]="60004588"
  ["Hek VIII - Moon 12 - Boundless Creation Factory"]="60005686"
  ["Onnamon VII – Caldari Navy Anchorage"]="60015184"
  ["Stacmon V - Moon 9 - Federation Navy Assembly Plant"]="60011893"
  ["Hodrold VII - Moon 8 - Thukker Mix"]="60014113"
  ["Torrinos V - Moon 5 - Lai Dai Corporation Factory"]="60002326"
  ["Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"]="60011575"
  ["Paye VI - Moon 1 - Imperial Academy"]="60014644"
  ["Oursulaert III - Federation Navy Testing Facilities"]="60011740"
  ["Tash-Murkon Prime II - Moon 1 - Kaalakiota Corporation Factory"]="60001096"
  ["Agil VI - Moon 2 - CONCORD"]="60012412"
  ["Perimeter - Tranquility Trading Tower"]="1028858195912"
  ["Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"]="60003478"
  ["Nourvukaiken V - State Protectorate Logistic Support"]="60015133"
  ["Sobaseki VII - Caldari Navy Logistic Support"]="60003916"
  ["Lustrevik VII - Moon 9 - Brutor Tribe Academy"]="60004609"
)

# Known region IDs
declare -A HUB_REGION_ID=(
  ["Jita IV - Moon 4 - Caldari Navy Assembly Plant"]="10000002"   # The Forge
  ["Amarr VIII (Oris) - Emperor Family Academy"]="10000043"       # Domain
  ["Dodixie IX - Moon 20 - Federation Navy Assembly Plant"]="10000032" # Sinq Laison
  ["Rens VI - Moon 8 - Brutor Tribe Treasury"]="10000030"         # Heimatar
  ["Hek VIII - Moon 12 - Boundless Creation Factory"]="10000042"  # Metropolis
  ["Onnamon VII – Caldari Navy Anchorage"]="10000069"  # Black Rise
  ["Stacmon V - Moon 9 - Federation Navy Assembly Plant"]="10000034"  # Placid
  ["Hodrold VII - Moon 8 - Thukker Mix"]="10000042"  # Metropolis
  ["Torrinos V - Moon 5 - Lai Dai Corporation Factory"]="10000043"  # Lonetrek
  ["Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"]="10000065"  # Kor-Azor
  ["Paye VI - Moon 1 - Imperial Academy"]="10000034"  # Placid
  ["Oursulaert III - Federation Navy Testing Facilities"]="10000064"  # Essence
  ["Tash-Murkon Prime II - Moon 1 - Kaalakiota Corporation Factory"]="10000020"  # Tash-Murkon
  ["Agil VI - Moon 2 - CONCORD"]="10000049"  # Khanid
  ["Perimeter - Tranquility Trading Tower"]="10000002"  # The Forge
  ["Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"]="10000065"  # Kor-Azor
  ["Nourvukaiken V - State Protectorate Logistic Support"]="10000016"  # Lonetrek
  ["Sobaseki VII - Caldari Navy Logistic Support"]="10000016"  # Lonetrek
  ["Lustrevik VII - Moon 9 - Brutor Tribe Academy"]="10000030"  # Heimatar
)

# Output files (note: Rens file name per your request)
declare -A HUB_FILE=(
  ["Jita IV - Moon 4 - Caldari Navy Assembly Plant"]="jita_buy.csv"
  ["Amarr VIII (Oris) - Emperor Family Academy"]="amarr_buy.csv"
  ["Dodixie IX - Moon 20 - Federation Navy Assembly Plant"]="dodixie_buy.csv"
  ["Rens VI - Moon 8 - Brutor Tribe Treasury"]="rens_but.csv"
  ["Hek VIII - Moon 12 - Boundless Creation Factory"]="hek_buy.csv"
  ["Onnamon VII – Caldari Navy Anchorage"]="onnamon_buy.csv"
  ["Stacmon V - Moon 9 - Federation Navy Assembly Plant"]="stacmon_buy.csv"
  ["Hodrold VII - Moon 8 - Thukker Mix"]="hodrold_buy.csv"
  ["Torrinos V - Moon 5 - Lai Dai Corporation Factory"]="torrinos_buy.csv"
  ["Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"]="zinkon_buy.csv"
  ["Paye VI - Moon 1 - Imperial Academy"]="paye_buy.csv"
  ["Oursulaert III - Federation Navy Testing Facilities"]="oursulaert_buy.csv"
  ["Tash-Murkon Prime II - Moon 1 - Kaalakiota Corporation Factory"]="tash_buy.csv"
  ["Agil VI - Moon 2 - CONCORD"]="agil_buy.csv"
  ["Perimeter - Tranquility Trading Tower"]="perimeter_buy.csv"
  ["Zinkon VII - Moon 1 - Caldari Business Tribunal Accounting"]="zinkon_buy.csv"
  ["Nourvukaiken V - State Protectorate Logistic Support"]="nourvukaiken_buy.csv"
  ["Sobaseki VII - Caldari Navy Logistic Support"]="sobaseki_buy.csv"
  ["Lustrevik VII - Moon 9 - Brutor Tribe Academy"]="lustrevik_buy.csv"
)

for hub in "${HUBS[@]}"; do
  echo "item_name,quantity,price" > "${HUB_FILE[$hub]}"
done

log() { [[ "$VERBOSE" == "1" ]] && echo -e "$*"; }

# Collect up to 10 HIGHEST station buy orders for a type_id.
# Prints N lines: "price,quantity"
get_top_buys_in_station() {
  local region_id="$1" station_id="$2" type_id="$3" want="${4:-10}"

  local hdr tmp pages
  hdr="$(mktemp)"; tmp="$(mktemp)"
  trap 'rm -f "$hdr" "$tmp"' RETURN

  # First page for X-Pages
  curl -sD "$hdr" -o "$tmp" \
    "$ESI/markets/$region_id/orders/?order_type=buy&type_id=$type_id&datasource=$DS&page=1"

  pages="$(awk -F': ' 'tolower($1)=="x-pages"{gsub(/\r/,"",$2);print $2}' "$hdr")"
  pages="${pages:-1}"

  jq --arg sid "$station_id" -r '
    map(select((.location_id|tostring)==$sid and (.range=="station")))
    | sort_by(.price) | reverse
    | .[] | "\(.price),\(.volume_remain)"
  ' "$tmp" | head -n "$want"

  local found
  found="$(jq --arg sid "$station_id" '
      map(select((.location_id|tostring)==$sid and (.range=="station"))) | length
    ' "$tmp")"

  if (( found < want )) && (( pages > 1 )); then
    local left=$((want - found))
    for ((p=2; p<=pages && left>0; p++)); do
      page_json="$(curl -s "$ESI/markets/$region_id/orders/?order_type=buy&type_id=$type_id&datasource=$DS&page=$p")"
      echo "$page_json" | jq --arg sid "$station_id" -r '
        map(select((.location_id|tostring)==$sid and (.range=="station")))
        | sort_by(.price) | reverse
        | .[] | "\(.price),\(.volume_remain)"
      ' | head -n "$left"
      left=$((left - $(echo "$page_json" | jq --arg sid "$station_id" 'map(select((.location_id|tostring)==$sid and (.range=="station"))) | length')))
      sleep 0.1
    done
  fi
}

# Read input and produce per-hub CSVs
total_items=$(($(wc -l < "$INPUT_CSV") - 1))
log "Processing ${total_items} items from ${INPUT_CSV}..."
idx=0

tail -n +2 "$INPUT_CSV" | while IFS=, read -r item_id item_name _rest; do
  idx=$((idx+1))
  item_id="${item_id//\"/}"
  item_name="${item_name//\"/}"
  [[ -z "$item_name" ]] && continue

  for hub in "${HUBS[@]}"; do
    out="${HUB_FILE[$hub]}"
    if [[ "$item_id" == "0000" || -z "$item_id" ]]; then
      echo "$item_name,0,0" >> "$out"
      continue
    fi

    [[ "$VERBOSE" == "1" ]] && echo -n "[${idx}/${total_items}] ${hub%% *} (BUY) :: ${item_name} ... "

    lines="$(get_top_buys_in_station "${HUB_REGION_ID[$hub]}" "${HUB_STATION_ID[$hub]}" "$item_id" 10 || true)"

    if [[ -z "$lines" ]]; then
      echo "$item_name,0,0" >> "$out"
      [[ "$VERBOSE" == "1" ]] && echo "none"
    else
      while IFS= read -r row; do
        price="${row%%,*}"
        qty="${row##*,}"
        echo "$item_name,$qty,$price" >> "$out"
      done <<< "$lines"
      [[ "$VERBOSE" == "1" ]] && echo "$(wc -l <<<"$lines" | tr -d '[:space:]') orders"
    fi
  done
done

log "Done -> ${HUB_FILE[@]}"
