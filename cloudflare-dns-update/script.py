import logging
from logging.handlers import RotatingFileHandler

import requests

LOG_FILE = "/Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/logs/cloudflare.log"

# Configure rotating log (5MB per file, keeps last 5 logs)
handler = RotatingFileHandler(LOG_FILE, maxBytes=5 * 1024 * 1024, backupCount=5)
logging.basicConfig(
    handlers=[handler],
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

env = {}

with open("/Users/nadeem/Documents/MacMiniServer/cloudflare-dns-update/.env", "r") as f:
    lines = f.read().split('\n')
    for line in lines:
        split_line = line.split('=')
        env[split_line[0]] = split_line[1]

api_token = env['API_TOKEN']
zone_id = env['ZONE_ID']


def health_check():
    logging.info("Performing health check")
    url = "https://health.nadee-mj.dev"
    try:
        response = requests.get(url, timeout=20)
        if response.status_code == 200:
            logging.info("Health check successful")
            return True
        else:
            logging.warning(
                f"Health check failed with status code: {response.status_code}"
            )
            return False
    except Exception as e:
        logging.error(f"Health check failed: {e}")
        return False


def get_public_ip():
    res = requests.get("https://cloudflare.com/cdn-cgi/trace")
    traces = res.text.split("\n")
    ip = [trace for trace in traces if "ip" in trace][0].split('=')[1]
    logging.info(f"Public IP: {ip}")
    return ip


def get_existing_dns_a_records():
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "Content-Type": "application/zone_id",
    }

    response = requests.get(url, headers=headers)
    records = response.json()["result"]
    records = [record for record in records if record["type"] == "A"]

    return records


def update_dns_a_records(ip):
    existing_records = get_existing_dns_a_records()
    success = True
    for record in existing_records:
        logging.info(f"Existing DNS record found: {record}")
        url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record['id']}"
        headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/zone_id",
        }
        data = {
            "content": ip,
        }

        try:
            response = requests.patch(url, json=data, headers=headers)
            if response.status_code == 200:
                logging.info(
                    f"DNS record {record['name']} updated successfully to {ip}"
                )
            else:
                logging.error(
                    f"Failed to update DNS record {record['name']}: {response.text}"
                )
                success = False
        except Exception as e:
            logging.error(f"Error updating DNS record {record['name']}: {e}")
            success = False

    return success


def main():
    if not health_check():
        new_ip = get_public_ip()
        response = update_dns_a_records(new_ip)
        logging.info(f"Updated DNS to {new_ip}" if response else "Failed to fully update DNS")
    else:
        logging.info("DNS is working fine. No update needed.")


if __name__ == "__main__":
    main()
