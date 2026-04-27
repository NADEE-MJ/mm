import { randomBytes } from "node:crypto";
import { envConfig } from "../config";

const SHARE_TTL_MINUTES = 5;

export type CopyPartyShareResult = {
  url: string;
  expiresAt: Date;
};

/**
 * Creates a 5-minute time-limited CopyParty share link for the given virtual
 * path inside the configured CopyParty instance.
 *
 * CopyParty share API:
 *   POST <baseUrl><virtualPath>?share
 *   Content-Type: application/json
 *   Body: { k, vp, perms, pw, exp }
 *
 * On success CopyParty responds 201 with a plain-text body:
 *   "created share: <full-url>"
 * The URL starts at character index 15 (after "created share: ").
 */
export const createCopyPartyShareLink = async (
  copypartyVirtualPath: string,
): Promise<CopyPartyShareResult> => {
  const baseUrl = envConfig.COPYPARTY_URL;
  if (!baseUrl) {
    throw new Error("COPYPARTY_URL is not configured");
  }

  // The virtual path for the IPA file includes the filename; strip the
  // trailing filename to get the folder path for the POST target URL.
  const lastSlash = copypartyVirtualPath.lastIndexOf("/");
  const folderPath = lastSlash > 0 ? copypartyVirtualPath.slice(0, lastSlash) : "/";
  const fileName = copypartyVirtualPath.slice(lastSlash + 1);

  // Generate a short random share key that satisfies CopyParty's character rules.
  const shareKey = randomBytes(8).toString("hex"); // 16 hex chars

  const postUrl = `${baseUrl.replace(/\/$/, "")}${folderPath}?share`;

  const body = {
    k: shareKey,
    // vp = list of virtual paths; a path without trailing "/" is treated as a file.
    vp: [copypartyVirtualPath],
    // "get" permission: visitors can download but cannot list the folder.
    perms: "get",
    pw: envConfig.COPYPARTY_PASSWORD ?? "",
    exp: SHARE_TTL_MINUTES,
  };

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "text/plain",
  };

  if (envConfig.COPYPARTY_PASSWORD) {
    headers["PW"] = envConfig.COPYPARTY_PASSWORD;
  }

  const response = await fetch(postUrl, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15_000),
  });

  if (!response.ok) {
    const text = await response.text().catch(() => "");
    throw new Error(
      `CopyParty share creation failed (${response.status}): ${text || response.statusText}`,
    );
  }

  const responseText = await response.text();

  // CopyParty responds: "created share: <url>"
  // The URL starts at index 15 per the CopyParty source.
  const PREFIX = "created share: ";
  if (!responseText.startsWith(PREFIX)) {
    throw new Error(`Unexpected CopyParty response: ${responseText}`);
  }

  const shrPrefix = envConfig.COPYPARTY_SHR_PREFIX.replace(/\/$/, "");
  let shareUrl = responseText.slice(PREFIX.length).trim();

  // Append the filename so the link is a direct file link, not just the share folder.
  // CopyParty constructs the share root URL; the individual file is at <root>/<filename>.
  if (fileName && !shareUrl.endsWith(`/${fileName}`)) {
    shareUrl = `${shareUrl.replace(/\/$/, "")}/${fileName}`;
  }

  // Add ?pw= to the URL if the share folder itself requires a password for the ?g permission.
  // (Only needed when the CopyParty volume requires auth even for `g` access.)
  if (envConfig.COPYPARTY_PASSWORD) {
    const separator = shareUrl.includes("?") ? "&" : "?";
    shareUrl = `${shareUrl}${separator}pw=${encodeURIComponent(envConfig.COPYPARTY_PASSWORD)}`;
  }

  const expiresAt = new Date(Date.now() + SHARE_TTL_MINUTES * 60 * 1000);

  return { url: shareUrl, expiresAt };
};
