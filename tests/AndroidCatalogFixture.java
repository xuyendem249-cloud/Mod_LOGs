package vn.anhchugia35.legend;

import java.io.BufferedOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.TreeMap;

/** Compare the iOS reader with the Android release on an authorized local disc. */
final class AndroidCatalogFixture {
    private static void writeString(DataOutputStream output, String value) throws IOException {
        byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
        output.writeInt(bytes.length);
        output.write(bytes);
    }

    public static void main(String[] args) throws IOException {
        try (GameData data = new GameData(new File(args[0]));
             DataOutputStream output = new DataOutputStream(
                     new BufferedOutputStream(new FileOutputStream(args[1])))) {
            output.writeInt(data.cardCount);
            output.writeInt(data.fusionCount);
            output.writeBoolean(data.hasNpc40);
            for (int id = 1; id <= data.cardCount; id++) {
                writeString(output, data.names[id]);
                writeString(output, data.descriptions[id]);
                output.writeInt(data.attribute(id, null));
                output.writeInt(data.type(id));
                for (int terrain = 0; terrain < 7; terrain++) {
                    int[] stats = data.stats(id, terrain, 0, null);
                    output.writeInt(stats[0]);
                    output.writeInt(stats[1]);
                }
                for (int pixel : data.art(id)) output.writeInt(pixel);
            }
            for (String type : data.typeNames) writeString(output, type);
            for (int[] icon : data.attrIcons) {
                output.writeInt(icon == null ? 0 : icon.length);
                if (icon != null) for (int pixel : icon) output.writeInt(pixel);
            }
            for (int[] icon : data.icons) for (int pixel : icon) output.writeInt(pixel);
            for (int npc = 0; npc < 40; npc++) {
                writeString(output, data.npcNames[npc]);
                for (int[] pool : data.pools[npc]) for (int value : pool) output.writeInt(value);
                for (int pixel : data.npcPhoto(npc)) output.writeInt(pixel);
            }
            for (int terrain = 0; terrain < 7; terrain++) {
                var pairs = new TreeMap<>(data.fusions(terrain));
                output.writeInt(pairs.size());
                for (var entry : pairs.entrySet()) {
                    output.writeInt(entry.getKey());
                    output.writeInt(entry.getValue());
                }
            }
        }
    }
}
