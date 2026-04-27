import dgram from "node:dgram";

const MAC_PATTERN = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;

export const createMagicPacket = (mac: string): Buffer => {
  if (!MAC_PATTERN.test(mac)) {
    throw new Error("Invalid MAC address format");
  }

  const macBytes = Buffer.from(mac.replaceAll(":", ""), "hex");
  const packet = Buffer.alloc(6 + 16 * macBytes.length, 0xff);

  for (let i = 0; i < 16; i += 1) {
    macBytes.copy(packet, 6 + i * macBytes.length);
  }

  return packet;
};

export const sendMagicPacket = async (
  mac: string,
  broadcastAddress: string,
  port = 9,
): Promise<void> => {
  const packet = createMagicPacket(mac);

  await new Promise<void>((resolve, reject) => {
    const socket = dgram.createSocket("udp4");

    socket.once("error", (error) => {
      socket.close();
      reject(error);
    });

    socket.bind(() => {
      socket.setBroadcast(true);
      socket.send(packet, port, broadcastAddress, (error) => {
        socket.close();
        if (error) {
          reject(error);
          return;
        }

        resolve();
      });
    });
  });
};
