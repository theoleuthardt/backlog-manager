import { Suspense, lazy } from "react";
import { BrowserRouter, Route, Routes } from "react-router";
import { RequireAuth } from "components/RequireAuth";
import { AppUpdater } from "~/app/_components/AppUpdater";
import { AuthProvider } from "~/app/context/AuthContext";
import { ThemeProvider } from "~/app/context/ThemeContext";
import { ApiProvider } from "~/lib/api/provider";
import { RoutePage } from "~/routes/RoutePage";
import { Toaster } from "~/components/ui/sonner";

const Home = lazy(() => import("~/app/page"));
const Login = lazy(() => import("~/app/login/page"));
const Dashboard = lazy(() => import("~/app/dashboard/page"));
const Space = lazy(() => import("~/app/space/page"));
const Steam = lazy(() => import("~/app/steam/page"));
const Account = lazy(() => import("~/app/account/page"));
const CreationTool = lazy(() => import("~/app/creation-tool/page"));
const ImportCsv = lazy(() => import("~/app/import-csv/page"));
const ExportCsv = lazy(() => import("~/app/export-csv/page"));
const Themes = lazy(() => import("~/app/themes/page"));
const Setup = lazy(() => import("~/app/setup/page"));

const page = (title: string, element: React.ReactNode, guarded = false) => (
  <RoutePage title={title}>
    {guarded ? <RequireAuth>{element}</RequireAuth> : element}
  </RoutePage>
);

export function App() {
  return (
    <BrowserRouter>
      <ApiProvider>
        <AuthProvider>
          <ThemeProvider>
            <Toaster />
            <Suspense fallback={null}>
              <Routes>
                <Route path="/" element={page("Backlog-Manager", <Home />)} />
                <Route path="/login" element={page("Login", <Login />)} />
                <Route
                  path="/dashboard"
                  element={page("Dashboard", <Dashboard />, true)}
                />
                <Route
                  path="/space"
                  element={page("Shared space", <Space />, true)}
                />
                <Route path="/steam" element={page("Steam", <Steam />, true)} />
                <Route
                  path="/account"
                  element={page("Account", <Account />, true)}
                />
                <Route
                  path="/creation-tool"
                  element={page("Creation Tool", <CreationTool />, true)}
                />
                <Route
                  path="/import-csv"
                  element={page("Import CSV", <ImportCsv />, true)}
                />
                <Route
                  path="/export-csv"
                  element={page("Export CSV", <ExportCsv />, true)}
                />
                <Route
                  path="/themes"
                  element={page("Theme Creator", <Themes />, true)}
                />
                <Route path="/setup" element={page("Setup", <Setup />, true)} />
                <Route path="*" element={page("Backlog-Manager", <Home />)} />
              </Routes>
            </Suspense>
          </ThemeProvider>
        </AuthProvider>
      </ApiProvider>
      <AppUpdater />
    </BrowserRouter>
  );
}
