import { Navbar } from "@components/Navbar";
import Starfield from "@components/Starfield";
import { Button } from "@components/Button";

export default function Home() {
  return (
    <div className="min-h-screen">
      <Starfield
        starCount={1000}
        starColor={[255, 255, 255]}
        speedFactor={0.05}
        backgroundColor="black"
      />
      <Navbar />
      <div className="pt-64 flex justify-center items-center">
        <div className="text-6xl text-white flex-1 flex justify-center items-center">
          <div className="flex flex-col text-center">
            <div>experience gaming with</div>
            <div>intention & appreciation</div>
            <div className="mt-9 flex flex-row">
              <Button
                className={"ml-40 mr-12 text-4xl p-6"}
                content={"get started"}
                link={"http://localhost:3000/auth/register"}
              />
              <Button
                className={"text-4xl p-6"}
                content={"github"}
                link={"https://github.com/theoleuthardt/backlog-manager"}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
