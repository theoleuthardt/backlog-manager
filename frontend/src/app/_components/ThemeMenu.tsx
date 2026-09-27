"use client";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { Palette } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "shadcn_components/ui/dropdown-menu";
import { useAuth } from "~/app/context/AuthContext";
import { useTheme } from "~/app/context/ThemeContext";
import { BUILTIN_THEMES, type ThemeColors } from "~/lib/themes";

const ThemeSwatch = ({ colors }: { colors: ThemeColors }) => (
  <span
    aria-hidden="true"
    className="flex h-4 w-8 shrink-0 overflow-hidden rounded-sm border border-white/40"
  >
    <span className="flex-1" style={{ backgroundColor: colors.background }} />
    <span className="flex-1" style={{ backgroundColor: colors.accent }} />
    <span className="flex-1" style={{ backgroundColor: colors.glow }} />
  </span>
);

export const ThemeMenu = () => {
  const router = useRouter();
  const { user } = useAuth();
  const { theme, customThemes, setTheme } = useTheme();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label="Change theme"
        className="flex h-8 w-8 cursor-pointer items-center justify-center rounded-md bg-transparent"
      >
        <Image
          src="/theme.png"
          alt="Theme"
          width={32}
          height={32}
          className="themed-icon"
        />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel>Theme</DropdownMenuLabel>
        <DropdownMenuRadioGroup
          value={theme.id}
          onValueChange={(value) => void setTheme(value)}
        >
          {BUILTIN_THEMES.map((builtin) => (
            <DropdownMenuRadioItem key={builtin.id} value={builtin.id}>
              <ThemeSwatch colors={builtin.colors} />
              {builtin.name}
            </DropdownMenuRadioItem>
          ))}
          {customThemes.length > 0 && (
            <>
              <DropdownMenuSeparator />
              <DropdownMenuLabel>Your themes</DropdownMenuLabel>
              {customThemes.map((custom) => (
                <DropdownMenuRadioItem key={custom.id} value={custom.id}>
                  <ThemeSwatch colors={custom} />
                  <span className="truncate">{custom.name}</span>
                </DropdownMenuRadioItem>
              ))}
            </>
          )}
        </DropdownMenuRadioGroup>
        {user && (
          <>
            <DropdownMenuSeparator />
            <DropdownMenuItem onSelect={() => router.push("/themes")}>
              <Palette className="h-4 w-4" />
              Theme creator
            </DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
