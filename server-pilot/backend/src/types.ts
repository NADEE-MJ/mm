export type KeyType = "A" | "B";

export type AppVariables = {
  deviceId: string;
  keyType: KeyType;
  idempotencyKey?: string;
  requestBodyHash: string;
};
