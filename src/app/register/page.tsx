import RegisterForm from "../_components/RegisterForm";

export default function RegisterPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-black text-white">
      <div className="container flex flex-col items-center justify-center gap-12 px-4 py-16 text-white">
        <h1 className="mb-6 text-5xl font-extrabold text-white sm:text-[5rem]">
          Create Account
        </h1>
        <RegisterForm />
      </div>
    </main>
  );
}
