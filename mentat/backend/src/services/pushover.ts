import { appConfig } from "../config";

export const sendPushover = async (title: string, message: string): Promise<void> => {
  if (!appConfig.alerts.pushoverApiToken || !appConfig.alerts.pushoverUserKey) {
    return;
  }

  const payload = new URLSearchParams({
    token: appConfig.alerts.pushoverApiToken,
    user: appConfig.alerts.pushoverUserKey,
    title,
    message,
  });

  const response = await fetch("https://api.pushover.net/1/messages.json", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: payload.toString(),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Pushover request failed: ${response.status} ${body}`);
  }
};
