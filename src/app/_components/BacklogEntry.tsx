import {
  Dialog,
  DialogContent,
  DialogTrigger,
  DialogHeader,
  DialogDescription,
  DialogTitle,
  DialogClose,
} from "shadcn_components/ui/dialog";
import { Button } from "shadcn_components/ui/button";
import GameImage from "components/GameImage";

interface BacklogEntryProps {
  title: string;
  imageLink: string;
  imageAlt?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  howLongToBeat?: number[];
  className?: string;
}

export const BacklogEntry = (props: BacklogEntryProps) => {
  return (
    <div
      className={`h-[14.0625rem] w-[9.375rem] cursor-pointer rounded-xl ${props.className}`}
    >
      <Dialog>
        <DialogTrigger asChild>
          <div>
            <GameImage
              src={props.imageLink ?? ""}
              alt={props.imageAlt ?? ""}
              width={150}
              height={225}
            />
          </div>
        </DialogTrigger>
        <DialogContent
          className="h-[40rem] w-[40rem] justify-center-safe border-2 border-white bg-black md:w-[50rem] lg:w-[70rem]"
          onOpenAutoFocus={(e) => e.preventDefault()}
        >
          <DialogClose asChild>
            <Button
              variant="destructive"
              size="icon"
              className="absolute top-2 right-2 h-8 w-8 fill-white p-0 text-white [&:focus]:ring-0 [&:focus]:outline-none [&:focus-visible]:ring-0"
            ></Button>
          </DialogClose>
          <DialogHeader>
            <DialogTitle className="text-center text-3xl text-white">
              {props.title}
            </DialogTitle>
            <DialogDescription>
              {props.note ?? "Lorem Ipsum and so on...."}
            </DialogDescription>
          </DialogHeader>
        </DialogContent>
      </Dialog>
    </div>
  );
};
