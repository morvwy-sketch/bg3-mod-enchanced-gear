using System.IO;
using K4os.Compression.LZ4.Streams;

namespace Native;

// Managed stand-in for the Windows-only LSLibNative LZ4 frame decoder, used only for solid PAK archives.
internal static class LZ4FrameCompressor
{
    public static byte[] Decompress(byte[] frame)
    {
        using var input = new MemoryStream(frame);
        using var lz4 = LZ4Stream.Decode(input);
        using var output = new MemoryStream();
        lz4.CopyTo(output);
        return output.ToArray();
    }
}
