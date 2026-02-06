import * as LocalAuthentication from 'expo-local-authentication';
import { Platform } from 'react-native';
import { getMetadata, setMetadata } from '../database/init';

/**
 * Check if biometric authentication is available on the device
 */
export async function isBiometricAvailable(): Promise<boolean> {
  try {
    const compatible = await LocalAuthentication.hasHardwareAsync();
    const enrolled = await LocalAuthentication.isEnrolledAsync();
    return compatible && enrolled;
  } catch (error) {
    console.error('Failed to check biometric availability:', error);
    return false;
  }
}

/**
 * Get the type of biometric authentication available
 */
export async function getBiometricType(): Promise<string> {
  try {
    const types = await LocalAuthentication.supportedAuthenticationTypesAsync();

    if (types.includes(LocalAuthentication.AuthenticationType.FACIAL_RECOGNITION)) {
      return Platform.OS === 'ios' ? 'Face ID' : 'Face Recognition';
    }

    if (types.includes(LocalAuthentication.AuthenticationType.FINGERPRINT)) {
      return Platform.OS === 'ios' ? 'Touch ID' : 'Fingerprint';
    }

    if (types.includes(LocalAuthentication.AuthenticationType.IRIS)) {
      return 'Iris Recognition';
    }

    return 'Biometric Authentication';
  } catch (error) {
    console.error('Failed to get biometric type:', error);
    return 'Biometric Authentication';
  }
}

/**
 * Authenticate using biometrics
 */
export async function authenticateWithBiometrics(): Promise<boolean> {
  try {
    const available = await isBiometricAvailable();

    if (!available) {
      console.log('Biometric authentication not available');
      return false;
    }

    const biometricType = await getBiometricType();

    const result = await LocalAuthentication.authenticateAsync({
      promptMessage: `Unlock with ${biometricType}`,
      fallbackLabel: 'Use passcode',
      cancelLabel: 'Cancel',
      disableDeviceFallback: false,
    });

    return result.success;
  } catch (error) {
    console.error('Biometric authentication failed:', error);
    return false;
  }
}

/**
 * Check if biometric authentication is enabled in app settings
 */
export async function isBiometricEnabled(): Promise<boolean> {
  try {
    const enabled = await getMetadata('biometric_enabled');
    return enabled === 'true';
  } catch (error) {
    console.error('Failed to check biometric enabled status:', error);
    return false;
  }
}

/**
 * Enable or disable biometric authentication in app settings
 */
export async function setBiometricEnabled(enabled: boolean): Promise<void> {
  try {
    await setMetadata('biometric_enabled', enabled ? 'true' : 'false');
  } catch (error) {
    console.error('Failed to set biometric enabled status:', error);
    throw error;
  }
}

/**
 * Prompt user to enable biometric authentication
 */
export async function promptEnableBiometric(): Promise<boolean> {
  try {
    const available = await isBiometricAvailable();

    if (!available) {
      return false;
    }

    // This will be called from a UI component that shows a dialog
    // For now, just return true to indicate biometric is available
    return true;
  } catch (error) {
    console.error('Failed to prompt biometric enable:', error);
    return false;
  }
}
