import React from 'react';
import { Pressable, StyleProp, StyleSheet, ViewStyle } from 'react-native';
import { COLORS } from '../../utils/constants';

interface CircleButtonProps {
  onPress: () => void;
  icon: React.ComponentType<{ size?: number; color?: string }>;
  size?: number;
  iconSize?: number;
  style?: StyleProp<ViewStyle>;
  iconColor?: string;
}

export default function CircleButton({
  onPress,
  icon: Icon,
  size = 36,
  iconSize = 18,
  style,
  iconColor = COLORS.text,
}: CircleButtonProps) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          opacity: pressed ? 0.75 : 1,
        },
        style,
      ]}
    >
      <Icon size={iconSize} color={iconColor} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    backgroundColor: '#2c2c2e',
    justifyContent: 'center',
    alignItems: 'center',
  },
});
