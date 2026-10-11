using System;
using System.IO;
using System.Linq;
using LSLib.LS;
using LSLib.LS.Enums;

namespace LsTool;

// Packer CLI for BG3 resources. Formats follow LSLib's BG3 settings (Game.BaldursGate3).
internal static class Program
{
    private const string Usage = @"usage:
  LsTool lsx2lsf <in.lsx> <out.lsf>
  LsTool lsf2lsx <in.lsf> <out.lsx>
  LsTool xml2loca <in.xml> <out.loca>
  LsTool loca2xml <in.loca> <out.xml>
  LsTool pack <dir> <out.pak>      (LSPK v18, LZ4)
  LsTool list <in.pak>
  LsTool unpack <in.pak> <dir>";

    private static int Main(string[] args)
    {
        try
        {
            return Run(args);
        }
        catch (Exception e)
        {
            Console.Error.WriteLine($"LsTool: {e.Message}");
            return 2;
        }
    }

    private static int Run(string[] rawArgs)
    {
        // LSLib requires absolute paths when creating directories.
        var args = rawArgs.Select((a, i) => i == 0 ? a : Path.GetFullPath(a)).ToArray();
        if (args.Length == 3)
        {
            switch (args[0])
            {
                case "lsx2lsf":
                    ConvertResource(args[1], args[2], ResourceFormat.LSX, ResourceFormat.LSF);
                    return 0;
                case "lsf2lsx":
                    ConvertResource(args[1], args[2], ResourceFormat.LSF, ResourceFormat.LSX);
                    return 0;
                case "xml2loca":
                    LocaUtils.Save(LocaUtils.Load(args[1], LocaFormat.Xml), args[2], LocaFormat.Loca);
                    return 0;
                case "loca2xml":
                    LocaUtils.Save(LocaUtils.Load(args[1], LocaFormat.Loca), args[2], LocaFormat.Xml);
                    return 0;
                case "pack":
                    Pack(args[1], args[2]);
                    return 0;
                case "unpack":
                    new Packager().UncompressPackage(args[1], args[2]);
                    return 0;
            }
        }

        if (args.Length == 2 && args[0] == "list")
        {
            List(args[1]);
            return 0;
        }

        Console.Error.WriteLine(Usage);
        return 1;
    }

    private static void ConvertResource(string input, string output, ResourceFormat inputFormat, ResourceFormat outputFormat)
    {
        var resource = ResourceUtils.LoadResource(input, inputFormat, ResourceLoadParameters.FromGameVersion(Game.BaldursGate3));
        ResourceUtils.SaveResource(resource, output, outputFormat, ResourceConversionParameters.FromGameVersion(Game.BaldursGate3));
    }

    private static void Pack(string inputDir, string pakPath)
    {
        var build = new PackageBuildData
        {
            Version = PackageVersion.V18,
            Compression = CompressionMethod.LZ4,
            CompressionLevel = LSCompressionLevel.Fast,
            Priority = 0,
        };
        new Packager().CreatePackage(pakPath, inputDir, build).GetAwaiter().GetResult();
    }

    private static void List(string pakPath)
    {
        using var package = new PackageReader().Read(pakPath);
        foreach (var file in package.Files.OrderBy(f => f.Name, StringComparer.Ordinal))
        {
            Console.WriteLine($"{file.Name}\t{file.Size()}");
        }
    }
}
