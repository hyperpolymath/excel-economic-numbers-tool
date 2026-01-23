# SPDX-License-Identifier: PMPL-1.0-or-later
"""
Report Generation - v7.0

Generate professional reports in PDF and PowerPoint formats.
"""

using Dates

struct ReportSection
    title::String
    content::String
    charts::Vector{String}  # Chart file paths or SVG strings
    level::Int  # Heading level
end

struct Report
    title::String
    author::String
    date::Date
    sections::Vector{ReportSection}
    theme::String
    cover_image::Union{String, Nothing}
end

"""
Create a new report
"""
function create_report(;
    title::String,
    author::String="Economic Toolkit",
    date::Date=today(),
    theme::String="professional"
)::Report

    return Report(
        title,
        author,
        date,
        ReportSection[],
        theme,
        nothing
    )
end

"""
Add section to report
"""
function add_section!(
    report::Report,
    title::String,
    content::String;
    charts::Vector{String}=String[],
    level::Int=1
)::Nothing

    section = ReportSection(title, content, charts, level)
    push!(report.sections, section)
    return nothing
end

"""
Generate PDF report (LaTeX-based)
"""
function generate_pdf(report::Report, output_file::String)::Bool
    # Generate LaTeX source
    latex = generate_latex(report)

    # Write to temporary file
    temp_file = tempname() * ".tex"
    write(temp_file, latex)

    try
        # Compile with pdflatex (requires LaTeX installation)
        run(`pdflatex -interaction=nonstopmode -output-directory=$(dirname(output_file)) $(temp_file)`)

        # Move PDF to output location
        pdf_file = replace(temp_file, ".tex" => ".pdf")
        if isfile(pdf_file)
            mv(pdf_file, output_file, force=true)
            @info "PDF report generated: $output_file"
            return true
        end
    catch e
        @error "PDF generation failed" exception=e
        return false
    end

    return false
end

"""
Generate LaTeX source
"""
function generate_latex(report::Report)::String
    latex = raw"""
\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{graphicx}
\usepackage{hyperref}
\usepackage{geometry}
\usepackage{fancyhdr}
\usepackage{booktabs}
\usepackage{xcolor}

\geometry{margin=1in}
\pagestyle{fancy}
\fancyhf{}
\rhead{\thepage}
\lhead{""" * report.title * raw"""}

\definecolor{primary}{RGB}{59,130,246}
\definecolor{secondary}{RGB}{16,185,129}

\title{\textbf{""" * report.title * raw"""}}
\author{""" * report.author * raw"""}
\date{""" * string(report.date) * raw"""}

\begin{document}

\maketitle
\tableofcontents
\newpage

"""

    # Add sections
    for section in report.sections
        if section.level == 1
            latex *= "\\section{" * section.title * "}\n\n"
        elseif section.level == 2
            latex *= "\\subsection{" * section.title * "}\n\n"
        else
            latex *= "\\subsubsection{" * section.title * "}\n\n"
        end

        latex *= section.content * "\n\n"

        # Add charts
        for chart in section.charts
            if isfile(chart)
                latex *= "\\begin{figure}[h]\n"
                latex *= "\\centering\n"
                latex *= "\\includegraphics[width=0.8\\textwidth]{" * chart * "}\n"
                latex *= "\\end{figure}\n\n"
            end
        end
    end

    latex *= raw"""
\end{document}
"""

    return latex
end

"""
Generate PowerPoint report (using python-pptx via external script)
"""
function generate_powerpoint(report::Report, output_file::String)::Bool
    # Generate Python script for python-pptx
    python_script = generate_pptx_script(report, output_file)

    # Write to temporary file
    temp_file = tempname() * ".py"
    write(temp_file, python_script)

    try
        # Run Python script
        run(`python3 $(temp_file)`)

        if isfile(output_file)
            @info "PowerPoint report generated: $output_file"
            return true
        end
    catch e
        @error "PowerPoint generation failed" exception=e
        return false
    end

    return false
end

"""
Generate python-pptx script
"""
function generate_pptx_script(report::Report, output_file::String)::String
    script = """
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN

# Create presentation
prs = Presentation()
prs.slide_width = Inches(10)
prs.slide_height = Inches(7.5)

# Title slide
title_slide_layout = prs.slide_layouts[0]
slide = prs.slides.add_slide(title_slide_layout)
title = slide.shapes.title
subtitle = slide.placeholders[1]

title.text = "$(report.title)"
subtitle.text = "$(report.author)\\n$(report.date)"

"""

    # Add section slides
    for section in report.sections
        script *= """
# Section: $(section.title)
slide_layout = prs.slide_layouts[1]  # Title and Content
slide = prs.slides.add_slide(slide_layout)
title = slide.shapes.title
title.text = "$(section.title)"

# Add content
left = Inches(1)
top = Inches(2)
width = Inches(8)
height = Inches(4)
txBox = slide.shapes.add_textbox(left, top, width, height)
tf = txBox.text_frame
tf.text = \"\"\"$(section.content)\"\"\"

"""

        # Add charts
        for (i, chart_path) in enumerate(section.charts)
            if isfile(chart_path)
                script *= """
# Add chart $(i)
left = Inches(1)
top = Inches($(3 + i * 2))
pic = slide.shapes.add_picture("$(chart_path)", left, top, width=Inches(4))

"""
            end
        end
    end

    script *= """
# Save presentation
prs.save("$(output_file)")
print("PowerPoint saved to $(output_file)")
"""

    return script
end

"""
Generate Markdown report
"""
function generate_markdown(report::Report)::String
    md = """
# $(report.title)

**Author:** $(report.author)
**Date:** $(report.date)

---

"""

    for section in report.sections
        # Add section heading
        md *= "#" ^ section.level * " " * section.title * "\n\n"

        # Add content
        md *= section.content * "\n\n"

        # Add charts
        for chart in section.charts
            if isfile(chart)
                md *= "![Chart]($(chart))\n\n"
            end
        end
    end

    return md
end

"""
Generate HTML report
"""
function generate_html(report::Report)::String
    html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(report.title)</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
        }
        h1 { color: #2563eb; border-bottom: 3px solid #2563eb; padding-bottom: 10px; }
        h2 { color: #3b82f6; margin-top: 30px; }
        h3 { color: #60a5fa; }
        .metadata { color: #666; font-size: 0.9em; margin-bottom: 30px; }
        img { max-width: 100%; height: auto; margin: 20px 0; }
        .chart { text-align: center; margin: 30px 0; }
        @media print {
            body { max-width: 100%; }
        }
    </style>
</head>
<body>
    <h1>$(report.title)</h1>
    <div class="metadata">
        <strong>Author:</strong> $(report.author)<br>
        <strong>Date:</strong> $(report.date)
    </div>
    <hr>
"""

    for section in report.sections
        tag = "h$(section.level)"
        html *= "    <$tag>$(section.title)</$tag>\n"
        html *= "    <div>$(replace(section.content, "\n" => "<br>"))</div>\n"

        for chart in section.charts
            if isfile(chart)
                html *= """    <div class="chart"><img src="$(chart)" alt="Chart"></div>\n"""
            elseif startswith(chart, "<svg")
                html *= """    <div class="chart">$(chart)</div>\n"""
            end
        end
    end

    html *= """
</body>
</html>
"""

    return html
end

"""
Export report in multiple formats
"""
function export_report(
    report::Report,
    base_filename::String;
    formats::Vector{String}=["pdf", "pptx", "md", "html"]
)::Dict{String, Bool}

    results = Dict{String, Bool}()

    for format in formats
        output_file = "$base_filename.$format"

        success = if format == "pdf"
            generate_pdf(report, output_file)
        elseif format in ["pptx", "ppt"]
            generate_powerpoint(report, output_file)
        elseif format == "md"
            write(output_file, generate_markdown(report))
            true
        elseif format == "html"
            write(output_file, generate_html(report))
            true
        else
            @warn "Unknown format: $format"
            false
        end

        results[format] = success
    end

    return results
end

export ReportSection, Report
export create_report, add_section!, generate_pdf, generate_powerpoint
export generate_markdown, generate_html, export_report
