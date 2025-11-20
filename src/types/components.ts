import type { ReactNode } from "react";
import type { BacklogEntryData } from "./backlog";
import type { NavbarLink } from "./navigation";

/**
 * UniSlider component props
 */
export interface UniSliderProps {
  className?: string;
  defaultValue: number;
  maxvalue: number;
  step: number;
  ref?: React.RefObject<HTMLInputElement>;
}

/**
 * Custom dropdown menu component props
 */
export interface DropdownMenuProps {
  className?: string;
  items: DropdownItem[];
  triggerText?: string;
  triggerIcon?: React.ReactNode;
}

/**
 * Dropdown menu item
 */
export interface DropdownItem {
  text: string;
}

/**
 * Game image component props
 */
export interface GameImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
  className?: string;
}

/**
 * Search bar component props
 */
export interface SearchBarProps {
  placeholder?: string;
  className?: string;
  onInput?: Function;
  onClear?: () => void;
  value?: string;
  ref?: React.RefObject<HTMLInputElement>;
  useIcon: boolean;
}

/**
 * Scroll section component props
 */
export interface ScrollSectionProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
}

/**
 * Entry creation dialog component props
 */
export interface EntryCreationDialogProps {
  triggerIcon?: string;
  triggerAlt?: string;
  triggerClassName?: string;
  showText?: boolean;
}

/**
 * Export CSV button component props
 */
export interface ExportCSVButtonProps {
  id?: string;
  disabled?: boolean;
  className?: string;
  children?: ReactNode;
  iconOnly?: boolean;
}

/**
 * Import CSV button component props
 */
export interface ImportCSVButtonProps {
  id?: string;
  disabled?: boolean;
  className?: string;
  children?: ReactNode;
  iconOnly?: boolean;
}

/**
 * Dashboard content component props
 */
export interface DashboardContentProps {
  initialData: BacklogEntryData[];
}

/**
 * Navbar component props
 */
export interface NavbarProps {
  navbarLinks: NavbarLink[];
}
