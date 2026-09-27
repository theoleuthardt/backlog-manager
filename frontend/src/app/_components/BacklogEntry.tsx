"use client";
import { motion } from "motion/react";
import { Dialog, DialogTrigger } from "shadcn_components/ui/dialog";
import { EntryTile } from "components/EntryTile";
import { EntryDetail } from "components/EntryDetail";
import type { BacklogEntryProps } from "~/app/types";

export const BacklogEntry = (props: BacklogEntryProps) => (
  <div
    className={`w-[9.375rem] cursor-pointer rounded-xl ${props.className ?? ""}`}
  >
    <Dialog>
      <DialogTrigger asChild>
        <motion.div
          className="leading-[0]"
          whileHover={{ scale: 1.05, y: -4 }}
          whileTap={{ scale: 0.98 }}
          transition={{ type: "spring", stiffness: 400, damping: 25 }}
        >
          <EntryTile
            title={props.title}
            imageLink={props.imageLink}
            imageAlt={props.imageAlt}
            status={props.status}
            playtime={props.playtime}
            mainTime={props.mainTime}
          />
        </motion.div>
      </DialogTrigger>
      <EntryDetail {...props} />
    </Dialog>
  </div>
);
