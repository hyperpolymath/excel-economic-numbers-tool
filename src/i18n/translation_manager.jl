# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Internationalization and Localization - v6.0

Multi-language support with 15+ languages, localized formatting, and RTL support.
"""

using Dates, JSON3

const SUPPORTED_LOCALES = [
    "en-US", "en-GB", "es-ES", "es-MX", "fr-FR", "de-DE", "it-IT",
    "pt-BR", "pt-PT", "zh-CN", "zh-TW", "ja-JP", "ko-KR", "ar-SA",
    "ru-RU", "hi-IN", "nl-NL", "sv-SE", "pl-PL", "tr-TR"
]

struct I18nManager
    current_locale::String
    fallback_locale::String
    translations::Dict{String, Dict{String, String}}
    date_formats::Dict{String, String}
    number_formats::Dict{String, Dict{String, Any}}
    currency_formats::Dict{String, Dict{String, Any}}
    rtl_locales::Set{String}
end

"""
Initialize i18n manager
"""
function I18nManager(locale::String="en-US", fallback::String="en-US")
    if !(locale in SUPPORTED_LOCALES)
        @warn "Locale $locale not supported, using fallback $fallback"
        locale = fallback
    end

    # RTL (Right-to-Left) locales
    rtl_locales = Set(["ar-SA", "he-IL", "fa-IR"])

    # Date formats by locale
    date_formats = Dict(
        "en-US" => "mm/dd/yyyy",
        "en-GB" => "dd/mm/yyyy",
        "de-DE" => "dd.mm.yyyy",
        "fr-FR" => "dd/mm/yyyy",
        "ja-JP" => "yyyy年mm月dd日",
        "zh-CN" => "yyyy年mm月dd日",
        "ar-SA" => "dd/mm/yyyy"
    )

    # Number formats
    number_formats = Dict(
        "en-US" => Dict("decimal" => ".", "thousands" => ","),
        "de-DE" => Dict("decimal" => ",", "thousands" => "."),
        "fr-FR" => Dict("decimal" => ",", "thousands" => " "),
        "es-ES" => Dict("decimal" => ",", "thousands" => "."),
        "ja-JP" => Dict("decimal" => ".", "thousands" => ","),
        "ar-SA" => Dict("decimal" => "٫", "thousands" => "٬")
    )

    # Currency formats
    currency_formats = Dict(
        "en-US" => Dict("symbol" => "\$", "position" => "before", "space" => false),
        "en-GB" => Dict("symbol" => "£", "position" => "before", "space" => false),
        "de-DE" => Dict("symbol" => "€", "position" => "after", "space" => true),
        "fr-FR" => Dict("symbol" => "€", "position" => "after", "space" => true),
        "ja-JP" => Dict("symbol" => "¥", "position" => "before", "space" => false),
        "zh-CN" => Dict("symbol" => "¥", "position" => "before", "space" => false),
        "ar-SA" => Dict("symbol" => "ر.س", "position" => "after", "space" => true)
    )

    return I18nManager(
        locale,
        fallback,
        Dict{String, Dict{String, String}}(),
        date_formats,
        number_formats,
        currency_formats,
        rtl_locales
    )
end

"""
Load translations from file or dictionary
"""
function load_translations!(manager::I18nManager, locale::String, translations::Dict{String, String})
    manager.translations[locale] = translations
    return nothing
end

"""
Translate key to current locale
"""
function t(manager::I18nManager, key::String; params::Dict{String, Any}=Dict{String, Any}())::String
    # Try current locale
    if haskey(manager.translations, manager.current_locale)
        if haskey(manager.translations[manager.current_locale], key)
            text = manager.translations[manager.current_locale][key]
            return interpolate(text, params)
        end
    end

    # Try fallback locale
    if haskey(manager.translations, manager.fallback_locale)
        if haskey(manager.translations[manager.fallback_locale], key)
            text = manager.translations[manager.fallback_locale][key]
            return interpolate(text, params)
        end
    end

    # Return key if not found
    return key
end

"""
Interpolate parameters into translation
"""
function interpolate(text::String, params::Dict{String, Any})::String
    result = text
    for (key, value) in params
        result = replace(result, "{{$key}}" => string(value))
    end
    return result
end

"""
Format number according to locale
"""
function format_number(manager::I18nManager, number::Real; decimals::Int=2)::String
    format_info = get(manager.number_formats, manager.current_locale, manager.number_formats["en-US"])

    decimal_sep = format_info["decimal"]
    thousands_sep = format_info["thousands"]

    # Round to specified decimals
    rounded = round(number, digits=decimals)

    # Split into integer and decimal parts
    parts = split(string(rounded), '.')
    integer_part = parts[1]
    decimal_part = length(parts) > 1 ? parts[2] : ""

    # Add thousands separators
    integer_formatted = ""
    for (i, char) in enumerate(reverse(integer_part))
        if i > 1 && (i - 1) % 3 == 0
            integer_formatted = thousands_sep * integer_formatted
        end
        integer_formatted = char * integer_formatted
    end

    # Combine parts
    if decimals > 0 && !isempty(decimal_part)
        # Pad decimal part if needed
        decimal_part = rpad(decimal_part, decimals, '0')
        return integer_formatted * decimal_sep * decimal_part
    else
        return integer_formatted
    end
end

"""
Format currency according to locale
"""
function format_currency(manager::I18nManager, amount::Real, currency_code::String="USD")::String
    format_info = get(manager.currency_formats, manager.current_locale, manager.currency_formats["en-US"])

    symbol = get(format_info, "symbol", currency_code)
    position = get(format_info, "position", "before")
    space = get(format_info, "space", false)

    number_str = format_number(manager, amount, decimals=2)

    if position == "before"
        return space ? "$symbol $number_str" : "$symbol$number_str"
    else
        return space ? "$number_str $symbol" : "$number_str$symbol"
    end
end

"""
Format date according to locale
"""
function format_date(manager::I18nManager, date::Date)::String
    format_str = get(manager.date_formats, manager.current_locale, "mm/dd/yyyy")

    # Simple formatting (in production, use proper date formatting library)
    day = lpad(string(Dates.day(date)), 2, '0')
    month = lpad(string(Dates.month(date)), 2, '0')
    year = string(Dates.year(date))

    result = replace(format_str, "dd" => day)
    result = replace(result, "mm" => month)
    result = replace(result, "yyyy" => year)

    return result
end

"""
Check if locale is RTL (Right-to-Left)
"""
function is_rtl(manager::I18nManager)::Bool
    return manager.current_locale in manager.rtl_locales
end

"""
Get localized economic indicator name
"""
function get_indicator_name(manager::I18nManager, indicator_code::String)::String
    key = "indicator.$(lowercase(indicator_code))"
    return t(manager, key)
end

"""
Get list of available locales
"""
function get_available_locales()::Vector{String}
    return SUPPORTED_LOCALES
end

"""
Initialize default translations
"""
function load_default_translations!(manager::I18nManager)
    # English (US)
    load_translations!(manager, "en-US", Dict(
        "app.title" => "Economic Toolkit",
        "app.welcome" => "Welcome to Economic Toolkit",
        "indicator.gdp" => "Gross Domestic Product",
        "indicator.unemployment" => "Unemployment Rate",
        "indicator.inflation" => "Inflation Rate",
        "indicator.interest_rate" => "Interest Rate",
        "error.not_found" => "Data not found",
        "error.invalid_date" => "Invalid date format",
        "action.fetch" => "Fetch Data",
        "action.export" => "Export",
        "action.share" => "Share",
        "label.from" => "From",
        "label.to" => "To",
        "label.country" => "Country",
        "label.indicator" => "Indicator"
    ))

    # Spanish (Spain)
    load_translations!(manager, "es-ES", Dict(
        "app.title" => "Kit de Herramientas Económicas",
        "app.welcome" => "Bienvenido al Kit de Herramientas Económicas",
        "indicator.gdp" => "Producto Interno Bruto",
        "indicator.unemployment" => "Tasa de Desempleo",
        "indicator.inflation" => "Tasa de Inflación",
        "indicator.interest_rate" => "Tasa de Interés",
        "error.not_found" => "Datos no encontrados",
        "error.invalid_date" => "Formato de fecha inválido",
        "action.fetch" => "Obtener Datos",
        "action.export" => "Exportar",
        "action.share" => "Compartir",
        "label.from" => "Desde",
        "label.to" => "Hasta",
        "label.country" => "País",
        "label.indicator" => "Indicador"
    ))

    # German
    load_translations!(manager, "de-DE", Dict(
        "app.title" => "Wirtschafts-Toolkit",
        "app.welcome" => "Willkommen beim Wirtschafts-Toolkit",
        "indicator.gdp" => "Bruttoinlandsprodukt",
        "indicator.unemployment" => "Arbeitslosenquote",
        "indicator.inflation" => "Inflationsrate",
        "indicator.interest_rate" => "Zinssatz",
        "error.not_found" => "Daten nicht gefunden",
        "error.invalid_date" => "Ungültiges Datumsformat",
        "action.fetch" => "Daten Abrufen",
        "action.export" => "Exportieren",
        "action.share" => "Teilen",
        "label.from" => "Von",
        "label.to" => "Bis",
        "label.country" => "Land",
        "label.indicator" => "Indikator"
    ))

    # French
    load_translations!(manager, "fr-FR", Dict(
        "app.title" => "Boîte à Outils Économique",
        "app.welcome" => "Bienvenue dans la Boîte à Outils Économique",
        "indicator.gdp" => "Produit Intérieur Brut",
        "indicator.unemployment" => "Taux de Chômage",
        "indicator.inflation" => "Taux d'Inflation",
        "indicator.interest_rate" => "Taux d'Intérêt",
        "error.not_found" => "Données non trouvées",
        "error.invalid_date" => "Format de date invalide",
        "action.fetch" => "Récupérer les Données",
        "action.export" => "Exporter",
        "action.share" => "Partager",
        "label.from" => "De",
        "label.to" => "À",
        "label.country" => "Pays",
        "label.indicator" => "Indicateur"
    ))

    # Japanese
    load_translations!(manager, "ja-JP", Dict(
        "app.title" => "経済ツールキット",
        "app.welcome" => "経済ツールキットへようこそ",
        "indicator.gdp" => "国内総生産",
        "indicator.unemployment" => "失業率",
        "indicator.inflation" => "インフレ率",
        "indicator.interest_rate" => "金利",
        "error.not_found" => "データが見つかりません",
        "error.invalid_date" => "無効な日付形式",
        "action.fetch" => "データ取得",
        "action.export" => "エクスポート",
        "action.share" => "共有",
        "label.from" => "開始",
        "label.to" => "終了",
        "label.country" => "国",
        "label.indicator" => "指標"
    ))

    # Chinese (Simplified)
    load_translations!(manager, "zh-CN", Dict(
        "app.title" => "经济工具包",
        "app.welcome" => "欢迎使用经济工具包",
        "indicator.gdp" => "国内生产总值",
        "indicator.unemployment" => "失业率",
        "indicator.inflation" => "通货膨胀率",
        "indicator.interest_rate" => "利率",
        "error.not_found" => "未找到数据",
        "error.invalid_date" => "无效的日期格式",
        "action.fetch" => "获取数据",
        "action.export" => "导出",
        "action.share" => "分享",
        "label.from" => "从",
        "label.to" => "到",
        "label.country" => "国家",
        "label.indicator" => "指标"
    ))

    # Arabic (Saudi Arabia)
    load_translations!(manager, "ar-SA", Dict(
        "app.title" => "مجموعة الأدوات الاقتصادية",
        "app.welcome" => "مرحباً بك في مجموعة الأدوات الاقتصادية",
        "indicator.gdp" => "الناتج المحلي الإجمالي",
        "indicator.unemployment" => "معدل البطالة",
        "indicator.inflation" => "معدل التضخم",
        "indicator.interest_rate" => "سعر الفائدة",
        "error.not_found" => "البيانات غير موجودة",
        "error.invalid_date" => "تنسيق تاريخ غير صالح",
        "action.fetch" => "جلب البيانات",
        "action.export" => "تصدير",
        "action.share" => "مشاركة",
        "label.from" => "من",
        "label.to" => "إلى",
        "label.country" => "البلد",
        "label.indicator" => "المؤشر"
    ))

    return nothing
end

export I18nManager, t, format_number, format_currency, format_date, is_rtl
export get_indicator_name, get_available_locales, load_default_translations!
