import type { ReactNode } from "react";
import type { NavbarLink } from "./navigation";

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
  onInput?: (e: React.ChangeEvent<HTMLInputElement>) => void;
  onClear?: () => void;
  value?: string;
  ref?: React.RefObject<HTMLInputElement>;
  useIcon?: boolean;
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
 * Navbar component props
 */
export interface NavbarProps {
  navbarLinks: NavbarLink[];
  center?: ReactNode;
}
