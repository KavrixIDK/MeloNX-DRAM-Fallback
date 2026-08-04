using Ryujinx.HLE.HOS.SystemState;
using System.Text.Json.Serialization;

namespace Ryujinx.Library.SystemNative
{
    [JsonConverter(typeof(JsonStringEnumConverter<Language>))]
    public enum Language
    {
        Japanese,
        AmericanEnglish,
        French,
        German,
        Italian,
        Spanish,
        Chinese,
        Korean,
        Dutch,
        Portuguese,
        Russian,
        Taiwanese,
        BritishEnglish,
        CanadianFrench,
        LatinAmericanSpanish,
        SimplifiedChinese,
        TraditionalChinese,
        BrazilianPortuguese,
        Polish,
        Thai,
    }

}
