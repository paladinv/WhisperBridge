export type EngineID =
  | "whisperCpp"
  | "moonshine"
  | "parakeet"
  | "moss"
  | "cohere"
  | "granite"
  | "canaryQwen";

export type OutputStyle = "plain" | "speakerTimestamped";

export interface ModelFileDescriptor {
  readonly path: string;
  readonly sizeBytes: number;
  readonly sha256: string;
}

export interface ModelDescriptor {
  readonly id: string;
  readonly displayName: string;
  readonly engine: EngineID;
  readonly repository: string;
  readonly revision: string;
  readonly license: string;
  readonly attribution: string;
  readonly languages: readonly string[];
  readonly automaticLanguageDetection: boolean;
  readonly outputStyle: OutputStyle;
  readonly estimatedPeakMemoryBytes: number;
  readonly minimumMacOS: string;
  readonly available: boolean;
  readonly unavailableReason?: string;
  readonly files: readonly ModelFileDescriptor[];
  readonly entryFile?: string;
}

const MiB = 1_048_576;

function hfFile(_repository: string, _revision: string, path: string, sizeBytes: number, sha256: string): ModelFileDescriptor {
  return { path, sizeBytes, sha256 };
}

const whisperLanguages = [
  "en", "zh", "de", "es", "ru", "ko", "fr", "ja", "pt", "tr", "pl", "ca", "nl", "ar", "sv", "it",
  "id", "hi", "fi", "vi", "he", "uk", "el", "ms", "cs", "ro", "da", "hu", "ta", "no", "th", "ur",
  "hr", "bg", "lt", "la", "mi", "ml", "cy", "sk", "te", "fa", "lv", "bn", "sr", "az", "sl", "kn",
  "et", "mk", "br", "eu", "is", "hy", "ne", "mn", "bs", "kk", "sq", "sw", "gl", "mr", "pa", "si",
  "km", "sn", "yo", "so", "af", "oc", "ka", "be", "tg", "sd", "gu", "am", "yi", "lo", "uz", "fo",
  "ht", "ps", "tk", "nn", "mt", "sa", "lb", "my", "bo", "tl", "mg", "as", "tt", "haw", "ln", "ha",
  "ba", "jw", "su"
] as const;

const parakeetLanguages = [
  "bg", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "de", "el", "hu", "it", "lv", "lt", "mt",
  "pl", "pt", "ro", "sk", "sl", "es", "sv", "ru", "uk"
] as const;

const cohereLanguages = ["ar", "de", "el", "en", "es", "fr", "it", "ja", "ko", "nl", "pl", "pt", "vi", "zh"] as const;
const graniteLanguages = ["en", "fr", "de", "es", "pt", "ja"] as const;
// The upstream model reports 50+ languages but publishes named evaluation coverage for these 14.
// Explicit selection stays conservative; automatic detection remains available for other speech.
const mossVerifiedLanguages = ["en", "fr", "de", "it", "pt", "es", "ja", "ko", "ru", "th", "vi", "tl", "ur", "tr"] as const;

const whisperRepository = "ggerganov/whisper.cpp";
const whisperRevision = "5359861c739e955e79d9a303bcbc70fb988958b1";

export const MODEL_CATALOG = [
  {
    id: "whisper-base-multilingual",
    displayName: "Everyday — Whisper Base Multilingual · 148 MB · about 388 MB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 388 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-base.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-base.bin", 147_951_465, "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")]
  },
  {
    id: "whisper-tiny-multilingual",
    displayName: "Smallest download — Whisper Tiny Multilingual · 78 MB · about 273 MB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 273 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-tiny.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-tiny.bin", 77_691_713, "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21")]
  },
  {
    id: "whisper-small-multilingual",
    displayName: "Better Whisper accuracy — Whisper Small Multilingual · 488 MB · about 852 MB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 852 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-small.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-small.bin", 487_601_967, "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b")]
  },
  {
    id: "whisper-small-q5",
    displayName: "Whisper Small Q5 — Lower-memory multilingual · 190 MB · about 600 MB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 600 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-small-q5_1.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-small-q5_1.bin", 190_085_487, "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb")]
  },
  {
    id: "whisper-small-q8",
    displayName: "Whisper Small Q8 — Balanced multilingual · 264 MB · about 700 MB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 700 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-small-q8_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-small-q8_0.bin", 264_464_607, "49c8fb02b65e6049d5fa6c04f81f53b867b5ec9540406812c643f177317f779f")]
  },
  {
    id: "whisper-small-english-q5",
    displayName: "Whisper Small English Q5 — English-only · 190 MB · about 600 MB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: ["en"],
    automaticLanguageDetection: false, outputStyle: "plain", estimatedPeakMemoryBytes: 600 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-small.en-q5_1.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-small.en-q5_1.bin", 190_098_681, "bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30")]
  },
  {
    id: "whisper-small-english-q8",
    displayName: "Whisper Small English Q8 — English-only · 264 MB · about 700 MB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: ["en"],
    automaticLanguageDetection: false, outputStyle: "plain", estimatedPeakMemoryBytes: 700 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-small.en-q8_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-small.en-q8_0.bin", 264_477_561, "67a179f608ea6114bd3fdb9060e762b588a3fb3bd00c4387971be4d177958067")]
  },
  {
    id: "whisper-small-english",
    displayName: "Whisper Small English — Full precision · 488 MB · about 852 MB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp", languages: ["en"],
    automaticLanguageDetection: false, outputStyle: "plain", estimatedPeakMemoryBytes: 852 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-small.en.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-small.en.bin", 487_614_201, "c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d")]
  },
  {
    id: "whisper-large-v3-turbo-q5",
    displayName: "Best Whisper accuracy — Large v3 Turbo Q5 · 574 MB · about 1.6 GB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 1_600 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-large-v3-turbo-q5_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v3-turbo-q5_0.bin", 574_041_195, "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2")]
  },
  {
    id: "whisper-medium-multilingual",
    displayName: "Whisper Medium — Multilingual · 1.53 GB · about 2.1 GB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 2_100 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-medium.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-medium.bin", 1_533_763_059, "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208")]
  },
  {
    id: "whisper-medium-q5",
    displayName: "Whisper Medium Q5 — Lower-memory multilingual · 539 MB · about 1.3 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 1_300 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-medium-q5_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-medium-q5_0.bin", 539_212_467, "19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f")]
  },
  {
    id: "whisper-medium-q8",
    displayName: "Whisper Medium Q8 — Balanced multilingual · 823 MB · about 1.6 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 1_600 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-medium-q8_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-medium-q8_0.bin", 823_369_779, "42a1ffcbe4167d224232443396968db4d02d4e8e87e213d3ee2e03095dea6502")]
  },
  {
    id: "whisper-medium-english-q5",
    displayName: "Whisper Medium English Q5 — English-only · 539 MB · about 1.3 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: ["en"],
    automaticLanguageDetection: false, outputStyle: "plain", estimatedPeakMemoryBytes: 1_300 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-medium.en-q5_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-medium.en-q5_0.bin", 539_225_533, "76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0")]
  },
  {
    id: "whisper-medium-english-q8",
    displayName: "Whisper Medium English Q8 — English-only · 823 MB · about 1.6 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: ["en"],
    automaticLanguageDetection: false, outputStyle: "plain", estimatedPeakMemoryBytes: 1_600 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-medium.en-q8_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-medium.en-q8_0.bin", 823_382_461, "43fa2cd084de5a04399a896a9a7a786064e221365c01700cea4666005218f11c")]
  },
  {
    id: "whisper-medium-english",
    displayName: "Whisper Medium English — Full precision · 1.53 GB · about 2.1 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp", languages: ["en"],
    automaticLanguageDetection: false, outputStyle: "plain", estimatedPeakMemoryBytes: 2_100 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-medium.en.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-medium.en.bin", 1_533_774_781, "cc37e93478338ec7700281a7ac30a10128929eb8f427dda2e865faa8f6da4356")]
  },
  {
    id: "whisper-large-v1-multilingual",
    displayName: "Whisper Large v1 — Multilingual · 3.09 GB · about 3.9 GB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 3_900 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-large-v1.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v1.bin", 3_094_623_691, "7d99f41a10525d0206bddadd86760181fa920438b6b33237e3118ff6c83bb53d")]
  },
  {
    id: "whisper-large-v2-multilingual",
    displayName: "Whisper Large v2 — Multilingual · 3.09 GB · about 3.9 GB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 3_900 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-large-v2.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v2.bin", 3_094_623_691, "9a423fe4d40c82774b6af34115b8b935f34152246eb19e80e376071d3f999487")]
  },
  {
    id: "whisper-large-v2-q5",
    displayName: "Whisper Large v2 Q5 — Lower-memory multilingual · 1.08 GB · about 2.4 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 2_400 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-large-v2-q5_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v2-q5_0.bin", 1_080_732_091, "3a214837221e4530dbc1fe8d734f302af393eb30bd0ed046042ebf4baf70f6f2")]
  },
  {
    id: "whisper-large-v2-q8",
    displayName: "Whisper Large v2 Q8 — Balanced multilingual · 1.66 GB · about 3 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 3_000 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-large-v2-q8_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v2-q8_0.bin", 1_656_129_691, "fef54e6d898246a65c8285bfa83bd1807e27fadf54d5d4e81754c47634737e8c")]
  },
  {
    id: "whisper-large-v3-multilingual",
    displayName: "Whisper Large v3 — Multilingual · 3.10 GB · about 3.9 GB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 3_900 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-large-v3.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v3.bin", 3_095_033_483, "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2")]
  },
  {
    id: "whisper-large-v3-q5",
    displayName: "Whisper Large v3 Q5 — Lower-memory multilingual · 1.08 GB · about 2.4 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 2_400 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-large-v3-q5_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v3-q5_0.bin", 1_081_140_203, "d75795ecff3f83b5faa89d1900604ad8c780abd5739fae406de19f23ecd98ad1")]
  },
  {
    id: "whisper-large-v3-turbo-full",
    displayName: "Whisper Large v3 Turbo — Full precision · 1.62 GB · about 2.6 GB memory · MIT",
    engine: "whisperCpp",
    repository: whisperRepository,
    revision: whisperRevision,
    license: "MIT",
    attribution: "OpenAI Whisper; GGML conversion by whisper.cpp",
    languages: whisperLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 2_600 * MiB,
    minimumMacOS: "14.0",
    available: true,
    entryFile: "ggml-large-v3-turbo.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v3-turbo.bin", 1_624_555_275, "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69")]
  },
  {
    id: "whisper-large-v3-turbo-q8",
    displayName: "Whisper Large v3 Turbo Q8 — Balanced multilingual · 874 MB · about 2 GB memory · MIT",
    engine: "whisperCpp", repository: whisperRepository, revision: whisperRevision, license: "MIT",
    attribution: "OpenAI Whisper; quantized GGML conversion by whisper.cpp", languages: whisperLanguages,
    automaticLanguageDetection: true, outputStyle: "plain", estimatedPeakMemoryBytes: 2_000 * MiB,
    minimumMacOS: "14.0", available: true, entryFile: "ggml-large-v3-turbo-q8_0.bin",
    files: [hfFile(whisperRepository, whisperRevision, "ggml-large-v3-turbo-q8_0.bin", 874_188_075, "317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1")]
  },
  {
    id: "moonshine-tiny-english",
    displayName: "Fast English — Moonshine Tiny · 110 MB · about 500 MB memory · MIT",
    engine: "moonshine",
    repository: "moonshine-ai/moonshine-tiny",
    revision: "390624ed33d594443aa4aa221f5b9f283b545b5a",
    license: "MIT",
    attribution: "Moonshine AI",
    languages: ["en"],
    automaticLanguageDetection: false,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 500 * MiB,
    minimumMacOS: "14.0",
    available: true,
    files: [
      hfFile("moonshine-ai/moonshine-tiny", "390624ed33d594443aa4aa221f5b9f283b545b5a", "config.json", 897, "47a43777a14e17b1ffd5f533e021d4d18c3c475cbb96de0947ce409e16444ded"),
      hfFile("moonshine-ai/moonshine-tiny", "390624ed33d594443aa4aa221f5b9f283b545b5a", "generation_config.json", 189, "a8e1437432c3ba7d0fca84ced5b3a254bf0c42b8e75fc336497cdcb56675e303"),
      hfFile("moonshine-ai/moonshine-tiny", "390624ed33d594443aa4aa221f5b9f283b545b5a", "model.safetensors", 108_389_192, "867cd2215804859c55aa972d740bd5002be149b4e7526328c895d2408848c736"),
      hfFile("moonshine-ai/moonshine-tiny", "390624ed33d594443aa4aa221f5b9f283b545b5a", "preprocessor_config.json", 215, "99272fe8ccfab114b68b478681ea47ee3a1ce62bb788cb92dd6e4f69fb1f1da2"),
      hfFile("moonshine-ai/moonshine-tiny", "390624ed33d594443aa4aa221f5b9f283b545b5a", "tokenizer.json", 1_985_530, "6579793438bc4fbafffacf699169ff53e3769c5a0a0f5e71cdee8853e8130deb")
    ]
  },
  {
    id: "parakeet-tdt-0.6b-v3-mlx-8bit",
    displayName: "European languages — Parakeet TDT 0.6B v3 · 909 MB · about 1.5 GB memory · CC BY 4.0",
    engine: "parakeet",
    repository: "littoralai/parakeet-tdt-0.6b-v3-mlx-8bit",
    revision: "c890f9db34cd0b273cf5f47eab068e32e72cc868",
    license: "CC-BY-4.0",
    attribution: "NVIDIA Parakeet; MLX conversion by mlx-community/animaslabs/littoralai",
    languages: parakeetLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 1_500 * MiB,
    minimumMacOS: "14.0",
    available: true,
    files: [
      hfFile("littoralai/parakeet-tdt-0.6b-v3-mlx-8bit", "c890f9db34cd0b273cf5f47eab068e32e72cc868", "config.json", 318_494, "4768f18c42b6609471aff2ae317831ab2d0861cb746b690f0207a3686251608b"),
      hfFile("littoralai/parakeet-tdt-0.6b-v3-mlx-8bit", "c890f9db34cd0b273cf5f47eab068e32e72cc868", "model.safetensors", 908_392_684, "3b11b8e228a2c865721f17ce7d7800cc5232872a53c3ed8f5140c1e3bd1b3ab2"),
      hfFile("littoralai/parakeet-tdt-0.6b-v3-mlx-8bit", "c890f9db34cd0b273cf5f47eab068e32e72cc868", "tokenizer.model", 360_916, "eacec2b0a77f336d4a2ca4a25a7047575d3c2b74de47e997f4c205126ed3135e"),
      hfFile("littoralai/parakeet-tdt-0.6b-v3-mlx-8bit", "c890f9db34cd0b273cf5f47eab068e32e72cc868", "tokenizer.vocab", 101_024, "41130ff456706304a1adec782ccc9e003c4d417e8e324353d281be958cac4e17")
    ]
  },
  {
    id: "moss-transcribe-diarize-0.9b-mlx-5bit",
    displayName: "Meetings and speakers — MOSS Transcribe Diarize 0.9B · 1.1 GB · about 1.3 GB memory · Apache 2.0",
    engine: "moss",
    repository: "aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit",
    revision: "88aa6b0de4816abc77f8e24384bce74fb087791a",
    license: "Apache-2.0",
    attribution: "OpenMOSS; MLX INT5 conversion by aufklarer",
    languages: mossVerifiedLanguages,
    automaticLanguageDetection: true,
    outputStyle: "speakerTimestamped",
    estimatedPeakMemoryBytes: 1_300 * MiB,
    minimumMacOS: "14.0",
    available: false,
    unavailableReason: "The reviewed 5-bit conversion is recorded but hidden because MLX Audio Swift 0.1.3 rejects its VQ-adaptor layout.",
    files: [
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "added_tokens.json", 707, "c0284b582e14987fbd3d5a2cb2bd139084371ed9acbae488829a1c900833c680"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "audio_encoder.safetensors", 624_970_399, "9cd0ac331cba4fddbd3c770e1ee327a8d03cbd65c740fcc4eafe9bbf0d21a71d"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "chat_template.jinja", 4_762, "8641466a16b184ebaf7c4903391e607cfd532ab937e81a64120628ab79d827f4"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "config.json", 1_035, "00875f06c84ca189d10ed87288f33e74c6d95b8d325a376122a951f3fe8546c5"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "decoder.safetensors", 409_944_112, "2870649eac5880797816be87ea8fc094ede789039715aa2a4edb1693a4735a71"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "generation_config.json", 107, "e53a4b3ce4f944230cf1ca8fed0c42f4ff0d8c1443eaf98b5315d987334dd9e4"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "merges.txt", 1_671_853, "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "preprocessor_config.json", 315, "ba2e601484abc80f4cded977f9a4fd4a53175b7d35c2f2511f0cfc3a32ad2499"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "processor_config.json", 292, "a978c2dd54a65b576c3dae4b654fe9bcbac1184c6db2df0afb2c90fcdc872ae7"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "special_tokens_map.json", 613, "76862e765266b85aa9459767e33cbaf13970f327a0e88d1c65846c2ddd3a1ecd"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "tokenizer.json", 11_423_222, "bcf03774334462d6e34b5005cb11120a62275f146ee2953e68731ecdbce84fbb"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "tokenizer_config.json", 503, "61d04c96104177240688396655ae3f7cf38ce2ea036db867a1d2b6883e27c3d5"),
      hfFile("aufklarer/MOSS-Transcribe-Diarize-0.9B-MLX-5bit", "88aa6b0de4816abc77f8e24384bce74fb087791a", "vocab.json", 2_776_833, "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910")
    ]
  },
  {
    id: "cohere-transcribe-2b-mlx-4bit",
    displayName: "High-accuracy multilingual — Cohere Transcribe 2B · 1.51 GB · about 2 GB memory · Apache 2.0",
    engine: "cohere",
    repository: "beshkenadze/cohere-transcribe-03-2026-mlx-4bit",
    revision: "104bc4391b5b1a12b040859793d7148525e1a08c",
    license: "Apache-2.0",
    attribution: "Cohere Labs; community MLX conversion by beshkenadze",
    languages: cohereLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 2_000 * MiB,
    minimumMacOS: "14.0",
    available: true,
    files: [
      hfFile("beshkenadze/cohere-transcribe-03-2026-mlx-4bit", "104bc4391b5b1a12b040859793d7148525e1a08c", "config.json", 4_336, "f5f4e46ea8a74e4e868d08504cb212afca7abfe55cd900d9b677bb2f9a1c210b"),
      hfFile("beshkenadze/cohere-transcribe-03-2026-mlx-4bit", "104bc4391b5b1a12b040859793d7148525e1a08c", "model.safetensors", 1_505_114_042, "5284ab5b678da720da092604323c7ce82cffe544e42b2da95064fbc85e281609"),
      hfFile("beshkenadze/cohere-transcribe-03-2026-mlx-4bit", "104bc4391b5b1a12b040859793d7148525e1a08c", "preprocessor_config.json", 420, "9f297d330646ecc8ebb9dc5784f48b7c35b118c913e306a1ccd0192f2c976332"),
      hfFile("beshkenadze/cohere-transcribe-03-2026-mlx-4bit", "104bc4391b5b1a12b040859793d7148525e1a08c", "special_tokens_map.json", 4_091, "1814ce01458ff6a72b04a6618e75f18ce627be4dc17619cd3a7cd7f71e137f0f"),
      hfFile("beshkenadze/cohere-transcribe-03-2026-mlx-4bit", "104bc4391b5b1a12b040859793d7148525e1a08c", "tokenizer.model", 492_827, "6d21e6a83b2d0d3e1241a7817e4bef8eb63bcb7cfe4a2675af9a35ff3bbf0e14"),
      hfFile("beshkenadze/cohere-transcribe-03-2026-mlx-4bit", "104bc4391b5b1a12b040859793d7148525e1a08c", "tokenizer_config.json", 48_141, "0dfeb3eeba07bccaa1b4bf78f3135ad3059acf8d18f681675832b285ac0035b0")
    ]
  },
  {
    id: "granite-4.0-1b-speech-mlx-5bit",
    displayName: "Granite Speech — Granite 4.0 · 2.23 GB · about 3 GB memory · Apache 2.0",
    engine: "granite",
    repository: "mlx-community/granite-4.0-1b-speech-5bit",
    revision: "371e6922faffba916e983e9c083049ad44536e94",
    license: "Apache-2.0",
    attribution: "IBM Granite; MLX conversion by mlx-community",
    languages: graniteLanguages,
    automaticLanguageDetection: true,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 3_000 * MiB,
    minimumMacOS: "14.0",
    available: true,
    files: [
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "added_tokens.json", 26, "b4956ad3505e979f2f25cc2e2be2163d8e23730f854b6c5a14ed106f3dd90549"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "config.json", 2_854, "0146532e775fce85b0cd5c1a482c697d49ddfc9eab6b732345f427861d94fa08"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "merges.txt", 916_646, "b6fe424e334903f7fb84d3a106d9730455f4744b9fe3c21ee136d97a00e72502"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "model.safetensors", 2_215_392_490, "ad1dd2cc653f61b8369e2c144d0181816b4b7179faa3953a872796611df02a60"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "model.safetensors.index.json", 120_558, "8b74691cf5cdfb33f6e6cba69e2ba0adc091790ea8ad734ffd11bbbc4cbac87f"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "preprocessor_config.json", 336, "382a6f26300937721969b01909c96c2e519620b6781f7b45cb8b2e348a932d87"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "processor_config.json", 80, "13edc723022827cc3620ba2e2b4bcf52287b365d77e60a31227f0a4b7dea5f9c"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "special_tokens_map.json", 579, "c08676c49fd7969a3130f72be6d4bf34da66aa484a6e21dffe359893a1bd5f2e"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "tokenizer.json", 7_153_607, "43ca88fd0519c64ef93fa0a90cbc4e560fe485b5ba60348a86bc3c624f37918e"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "tokenizer_config.json", 17_882, "de233c19cd9efa63738f7481f318fc2048060f751ac9fd7957b131c43226b403"),
      hfFile("mlx-community/granite-4.0-1b-speech-5bit", "371e6922faffba916e983e9c083049ad44536e94", "vocab.json", 1_612_704, "8af71076de8b0b626eed0f4c984faf0a7c062479164b2a31308a948524d4f69c")
    ]
  },
  {
    id: "canary-qwen-2.5b",
    displayName: "Canary-Qwen 2.5B",
    engine: "canaryQwen",
    repository: "nvidia/canary-qwen-2.5b",
    revision: "unavailable",
    license: "CC-BY-4.0",
    attribution: "NVIDIA Canary-Qwen",
    languages: ["en"],
    automaticLanguageDetection: false,
    outputStyle: "plain",
    estimatedPeakMemoryBytes: 6_000 * MiB,
    minimumMacOS: "14.0",
    available: false,
    unavailableReason: "The exact Canary-Qwen checkpoint does not yet have a verified native Swift conversion.",
    files: []
  }
] as const satisfies readonly ModelDescriptor[];

export type ModelID = (typeof MODEL_CATALOG)[number]["id"];
export const DEFAULT_MODEL_ID: ModelID = "whisper-base-multilingual";

export const AVAILABLE_MODELS = MODEL_CATALOG.filter(model => model.available);

const languageNames = new Intl.DisplayNames(["en"], { type: "language" });
export const LANGUAGE_OPTIONS = [
  { value: "auto", displayName: "Detect automatically" },
  ...Array.from(new Set(AVAILABLE_MODELS.flatMap(model => model.languages)))
    .map(value => ({ value, displayName: languageNames.of(value) ?? value }))
    .sort((left, right) => left.displayName.localeCompare(right.displayName))
];

export function modelByID(id: string): ModelDescriptor | undefined {
  return MODEL_CATALOG.find(model => model.id === id);
}

export function modelDownloadBytes(model: ModelDescriptor): number {
  return model.files.reduce((total, file) => total + file.sizeBytes, 0);
}

export function modelFileURL(model: ModelDescriptor, file: ModelFileDescriptor): string {
  const encodedPath = file.path.split("/").map(encodeURIComponent).join("/");
  return `https://huggingface.co/${model.repository}/resolve/${model.revision}/${encodedPath}`;
}

export function supportsLanguage(model: ModelDescriptor, language: string): boolean {
  if (language === "auto") return model.automaticLanguageDetection || model.languages.length === 1;
  return model.languages.includes(language);
}
