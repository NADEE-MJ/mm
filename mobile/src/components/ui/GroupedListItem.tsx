import React, { ReactNode } from 'react';
import { Pressable, StyleProp, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { ChevronRight } from 'lucide-react-native';
import { COLORS } from '../../utils/constants';

interface GroupedListItemProps {
  title: string;
  subtitle?: string;
  left?: ReactNode;
  right?: ReactNode;
  onPress?: () => void;
  style?: StyleProp<ViewStyle>;
  showChevron?: boolean;
  showDivider?: boolean;
  disabled?: boolean;
}

export default function GroupedListItem({
  title,
  subtitle,
  left,
  right,
  onPress,
  style,
  showChevron = true,
  showDivider = false,
  disabled = false,
}: GroupedListItemProps) {
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || !onPress}
      style={({ pressed }) => [
        styles.row,
        pressed && onPress ? styles.pressed : undefined,
        showDivider ? styles.divider : undefined,
        style,
      ]}
    >
      {left ? <View style={styles.left}>{left}</View> : null}

      <View style={styles.textWrap}>
        <Text style={styles.title} numberOfLines={1}>
          {title}
        </Text>
        {subtitle ? (
          <Text style={styles.subtitle} numberOfLines={1}>
            {subtitle}
          </Text>
        ) : null}
      </View>

      <View style={styles.rightWrap}>
        {right}
        {showChevron ? <ChevronRight size={16} color={COLORS.textSecondary} /> : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 56,
    paddingHorizontal: 14,
    paddingVertical: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  pressed: {
    opacity: 0.7,
  },
  divider: {
    borderBottomWidth: 0.5,
    borderBottomColor: COLORS.separator,
  },
  left: {
    width: 34,
    alignItems: 'center',
    justifyContent: 'center',
  },
  textWrap: {
    flex: 1,
    minWidth: 0,
  },
  title: {
    color: COLORS.text,
    fontSize: 16,
    fontWeight: '600',
  },
  subtitle: {
    color: COLORS.textSecondary,
    fontSize: 13,
    marginTop: 2,
  },
  rightWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
});
