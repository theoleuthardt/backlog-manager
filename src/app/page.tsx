import { Navbar } from "@components/Navbar";
import Starfield from "@components/Starfield";
import { ButtonInverted } from "@components/ButtonInverted";
import Image from "next/image";
import { pictures } from "@/app/constants/pictures";
import { ButtonWithImage } from "@components/ButtonWithImage";
import { icons } from "@/app/constants/icons";

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
      <div className="">
        <div className="w-screen flex justify-end pr-11 absolute">
          <Image
            src={pictures[0].src}
            alt={pictures[0].alt}
            width={pictures[0].width}
            height={pictures[0].height}
          />
        </div>
        <div className="text-6xl text-white pt-64 flex-1 flex justify-center items-center">
          <div className="flex flex-col text-center relative">
            <div>experience gaming with</div>
            <div>intention & appreciation</div>
            <div className="mt-9 flex flex-row">
              <ButtonInverted
                className={"ml-40 mr-12 text-4xl p-6 bg-white text-black"}
                content={"get started"}
                link={"http://localhost:3000/auth/register"}
              />
              <ButtonWithImage
                className={"text-4xl p-6 bg-white text-black"}
                text={"github"}
                image={icons[2]}
                link={"https://github.com/theoleuthardt/backlog-manager"}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
