import { Button } from "@components/Button";
import { icons } from "@/app/constants/icons";
import Image from "next/image";

export const Navbar = () => {
  return (
    <div className="mt-1 flex flex-row items-center min-w-screen">
      <div className="flex justify-start flex-1 text-white text-2xl pl-5">
        <div className="filter invert pr-3 hover:animate-pulse">
          {icons[1] ? (
            <Image
              src={icons[1].src}
              alt={icons[1].alt}
              width={icons[1].width}
              height={icons[1].height}
            />
          ) : null}
        </div>
        <h1>backlog manager.</h1>
      </div>
      <div className="flex justify-center items-center flex-1 max-w-screen-lg">
        <div
          className={`h-20 px-5 space-x-5 text-xl text-white
                    flex items-center justify-center max-w-screen-xl`}
        >
          <div className="">
            <Button
              className="w-28"
              content="home"
              link="http://localhost:3000"
            />
          </div>
          <div className="">
            <Button
              className="w-28"
              content="manager"
              link="http://localhost:3000/manager"
            />
          </div>
          <div className="">
            <Button
              className="w-28"
              content="import"
              link="http://localhost:3000/import"
            />
          </div>
        </div>
      </div>
      <div className="flex justify-end flex-1 pr-5">
        <Button
          className="w-14 h-14"
          content={icons.at(0)}
          link={"http://localhost/auth/login"}
        />
      </div>
    </div>
  );
};
