import React, { ReactNode } from 'react';
import { StyleProp, StyleSheet, View, ViewStyle } from 'react-native';
import { COLORS } from '../../utils/constants';

interface GroupedListProps {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}

export default function GroupedList({ children, style }: GroupedListProps) {
  const items = React.Children.toArray(children).filter(Boolean);

  return (
    <View style={[styles.container, style]}>
      {items.map((item, index) => (
        <View
          // `React.Children.toArray` keeps element keys when available.
          key={(item as any)?.key ?? index}
          style={index < items.length - 1 ? styles.divider : undefined}
        >
          {item}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.surfaceGroup,
    borderRadius: 12,
    overflow: 'hidden',
  },
  divider: {
    borderBottomWidth: 0.5,
    borderBottomColor: COLORS.separator,
  },
});
