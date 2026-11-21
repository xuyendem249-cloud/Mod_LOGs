package vn.anhchugia35.legend;

import java.io.BufferedOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/** An oracle from the production Android reader and planner, driven by a private editor capture. */
final class AndroidInventoryFixture {
    static void writeItems(DataOutputStream output, int[] values) throws IOException {
        for (int value : values) output.writeInt(value);
    }

    public static void main(String[] args) throws IOException {
        byte[] ram = Files.readAllBytes(Path.of(args[1]));
        try (GameData data = new GameData(new File(args[0]));
             DataOutputStream output = new DataOutputStream(
                     new BufferedOutputStream(new FileOutputStream(args[2])))) {
            CollectionSnapshot view = CollectionSnapshot.read(ram, data.cardCount);
            if (view == null) throw new IOException("Android rejected live editor");
            output.writeInt(data.cardCount);
            output.writeInt(view.base);
            output.writeInt(view.deckList);
            output.writeInt(view.size);
            output.writeInt(view.pane);
            writeItems(output, view.chest);
            writeItems(output, view.deck);
            writeItems(output, view.limits);
            writeItems(output, view.slots);
            for (int terrain = 0; terrain < 7; terrain++) {
                DeckPlanner.Plan plan = DeckPlanner.build(data, view, terrain);
                output.writeInt(plan.target);
                output.writeInt(plan.attack);
                output.writeInt(plan.defense);
                output.writeInt(plan.materials.length);
                writeItems(output, plan.materials);
                writeItems(output, plan.cards);
            }
        }
    }
}
