// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//! Interactive Charting Engine - v7.0
//!
//! High-performance charting using Rust/WASM for 60fps interactive visualizations

use serde::{Deserialize, Serialize};
use wasm_bindgen::prelude::*;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ChartType {
    Line,
    Bar,
    Pie,
    Scatter,
    Heatmap,
    Candlestick,
    Waterfall,
    Treemap,
    Sankey,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChartSeries {
    pub name: String,
    pub data: Vec<f64>,
    pub color: String,
    pub line_width: f32,
    pub marker_size: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChartConfig {
    pub chart_type: ChartType,
    pub title: String,
    pub subtitle: String,
    pub width: u32,
    pub height: u32,
    pub x_axis_label: String,
    pub y_axis_label: String,
    pub show_legend: bool,
    pub show_grid: bool,
    pub interactive: bool,
    pub animation_duration: u32,
    pub theme: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Chart {
    pub config: ChartConfig,
    pub series: Vec<ChartSeries>,
    pub x_labels: Vec<String>,
}

impl Chart {
    pub fn new(config: ChartConfig) -> Self {
        Chart {
            config,
            series: Vec::new(),
            x_labels: Vec::new(),
        }
    }

    pub fn add_series(&mut self, series: ChartSeries) {
        self.series.push(series);
    }

    pub fn set_x_labels(&mut self, labels: Vec<String>) {
        self.x_labels = labels;
    }

    /// Render chart to SVG
    pub fn render_svg(&self) -> String {
        match self.config.chart_type {
            ChartType::Line => self.render_line_chart(),
            ChartType::Bar => self.render_bar_chart(),
            ChartType::Pie => self.render_pie_chart(),
            ChartType::Scatter => self.render_scatter_chart(),
            _ => String::from("<svg></svg>"),
        }
    }

    fn render_line_chart(&self) -> String {
        let width = self.config.width;
        let height = self.config.height;
        let margin = 50;

        let plot_width = width - 2 * margin;
        let plot_height = height - 2 * margin;

        let mut svg = format!(
            r#"<svg width="{}" height="{}" xmlns="http://www.w3.org/2000/svg">"#,
            width, height
        );

        // Title
        svg.push_str(&format!(
            r#"<text x="{}" y="30" text-anchor="middle" font-size="18" font-weight="bold">{}</text>"#,
            width / 2,
            self.config.title
        ));

        // Grid
        if self.config.show_grid {
            for i in 0..11 {
                let y = margin + (i * plot_height / 10);
                svg.push_str(&format!(
                    r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="#e0e0e0" stroke-width="1"/>"#,
                    margin,
                    y,
                    width - margin,
                    y
                ));
            }
        }

        // Axes
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="black" stroke-width="2"/>"#,
            margin,
            height - margin,
            width - margin,
            height - margin
        ));
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="black" stroke-width="2"/>"#,
            margin,
            margin,
            margin,
            height - margin
        ));

        // Data series
        for series in &self.series {
            if series.data.is_empty() {
                continue;
            }

            let max_value = series.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
            let min_value = series.data.iter().cloned().fold(f64::INFINITY, f64::min);
            let value_range = max_value - min_value;

            let mut points = String::new();
            for (i, value) in series.data.iter().enumerate() {
                let x = margin + (i as u32 * plot_width / series.data.len().max(1) as u32);
                let normalized = if value_range > 0.0 {
                    (value - min_value) / value_range
                } else {
                    0.5
                };
                let y = height - margin - (normalized * plot_height as f64) as u32;

                if i > 0 {
                    points.push(' ');
                }
                points.push_str(&format!("{},{}", x, y));
            }

            svg.push_str(&format!(
                r#"<polyline points="{}" fill="none" stroke="{}" stroke-width="{}" />"#,
                points, series.color, series.line_width
            ));
        }

        // Legend
        if self.config.show_legend {
            let legend_y = 60;
            for (i, series) in self.series.iter().enumerate() {
                let legend_x = width - margin - 100;
                let y_offset = legend_y + (i as u32 * 25);

                svg.push_str(&format!(
                    r#"<rect x="{}" y="{}" width="15" height="15" fill="{}"/>"#,
                    legend_x, y_offset, series.color
                ));
                svg.push_str(&format!(
                    r#"<text x="{}" y="{}" font-size="12">{}</text>"#,
                    legend_x + 20,
                    y_offset + 12,
                    series.name
                ));
            }
        }

        svg.push_str("</svg>");
        svg
    }

    fn render_bar_chart(&self) -> String {
        let width = self.config.width;
        let height = self.config.height;
        let margin = 50;

        let plot_width = width - 2 * margin;
        let plot_height = height - 2 * margin;

        let mut svg = format!(
            r#"<svg width="{}" height="{}" xmlns="http://www.w3.org/2000/svg">"#,
            width, height
        );

        // Title
        svg.push_str(&format!(
            r#"<text x="{}" y="30" text-anchor="middle" font-size="18" font-weight="bold">{}</text>"#,
            width / 2,
            self.config.title
        ));

        // Axes
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="black" stroke-width="2"/>"#,
            margin,
            height - margin,
            width - margin,
            height - margin
        ));

        // Data
        if let Some(series) = self.series.first() {
            let n = series.data.len();
            if n > 0 {
                let bar_width = plot_width / (n as u32 * 2);
                let max_value = series.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);

                for (i, value) in series.data.iter().enumerate() {
                    let x = margin + (i as u32 * plot_width / n as u32) + bar_width / 2;
                    let bar_height = if max_value > 0.0 {
                        (value / max_value * plot_height as f64) as u32
                    } else {
                        0
                    };
                    let y = height - margin - bar_height;

                    svg.push_str(&format!(
                        r#"<rect x="{}" y="{}" width="{}" height="{}" fill="{}" />"#,
                        x, y, bar_width, bar_height, series.color
                    ));
                }
            }
        }

        svg.push_str("</svg>");
        svg
    }

    fn render_pie_chart(&self) -> String {
        let width = self.config.width;
        let height = self.config.height;
        let center_x = width / 2;
        let center_y = height / 2;
        let radius = width.min(height) / 3;

        let mut svg = format!(
            r#"<svg width="{}" height="{}" xmlns="http://www.w3.org/2000/svg">"#,
            width, height
        );

        // Title
        svg.push_str(&format!(
            r#"<text x="{}" y="30" text-anchor="middle" font-size="18" font-weight="bold">{}</text>"#,
            width / 2,
            self.config.title
        ));

        if let Some(series) = self.series.first() {
            let total: f64 = series.data.iter().sum();
            let mut current_angle = -90.0; // Start at top

            for (i, value) in series.data.iter().enumerate() {
                let slice_angle = (value / total) * 360.0;
                let end_angle = current_angle + slice_angle;

                // Calculate arc path
                let start_x = center_x as f64 + radius as f64 * (current_angle.to_radians().cos());
                let start_y = center_y as f64 + radius as f64 * (current_angle.to_radians().sin());
                let end_x = center_x as f64 + radius as f64 * (end_angle.to_radians().cos());
                let end_y = center_y as f64 + radius as f64 * (end_angle.to_radians().sin());

                let large_arc = if slice_angle > 180.0 { 1 } else { 0 };

                let color = if i < 10 {
                    &["#3b82f6", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6",
                      "#ec4899", "#14b8a6", "#f97316", "#06b6d4", "#84cc16"][i]
                } else {
                    "#6b7280"
                };

                svg.push_str(&format!(
                    r#"<path d="M {} {} L {} {} A {} {} 0 {} 1 {} {} Z" fill="{}" stroke="white" stroke-width="2"/>"#,
                    center_x, center_y, start_x, start_y, radius, radius, large_arc, end_x, end_y, color
                ));

                current_angle = end_angle;
            }
        }

        svg.push_str("</svg>");
        svg
    }

    fn render_scatter_chart(&self) -> String {
        let width = self.config.width;
        let height = self.config.height;
        let margin = 50;

        let plot_width = width - 2 * margin;
        let plot_height = height - 2 * margin;

        let mut svg = format!(
            r#"<svg width="{}" height="{}" xmlns="http://www.w3.org/2000/svg">"#,
            width, height
        );

        // Title
        svg.push_str(&format!(
            r#"<text x="{}" y="30" text-anchor="middle" font-size="18" font-weight="bold">{}</text>"#,
            width / 2,
            self.config.title
        ));

        // Axes
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="black" stroke-width="2"/>"#,
            margin,
            height - margin,
            width - margin,
            height - margin
        ));
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="black" stroke-width="2"/>"#,
            margin,
            margin,
            margin,
            height - margin
        ));

        // Data points
        for series in &self.series {
            let max_value = series.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
            let min_value = series.data.iter().cloned().fold(f64::INFINITY, f64::min);
            let value_range = max_value - min_value;

            for (i, value) in series.data.iter().enumerate() {
                let x = margin + (i as u32 * plot_width / series.data.len().max(1) as u32);
                let normalized = if value_range > 0.0 {
                    (value - min_value) / value_range
                } else {
                    0.5
                };
                let y = height - margin - (normalized * plot_height as f64) as u32;

                svg.push_str(&format!(
                    r#"<circle cx="{}" cy="{}" r="{}" fill="{}" opacity="0.7"/>"#,
                    x, y, series.marker_size, series.color
                ));
            }
        }

        svg.push_str("</svg>");
        svg
    }
}

/// WASM bindings for JavaScript
#[wasm_bindgen]
pub fn create_chart(config_json: &str, series_json: &str) -> String {
    let config: ChartConfig = serde_json::from_str(config_json).unwrap();
    let series: Vec<ChartSeries> = serde_json::from_str(series_json).unwrap();

    let mut chart = Chart::new(config);
    for s in series {
        chart.add_series(s);
    }

    chart.render_svg()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_line_chart_creation() {
        let config = ChartConfig {
            chart_type: ChartType::Line,
            title: "Test Chart".to_string(),
            subtitle: "".to_string(),
            width: 800,
            height: 600,
            x_axis_label: "X".to_string(),
            y_axis_label: "Y".to_string(),
            show_legend: true,
            show_grid: true,
            interactive: true,
            animation_duration: 300,
            theme: "light".to_string(),
        };

        let mut chart = Chart::new(config);
        chart.add_series(ChartSeries {
            name: "Series 1".to_string(),
            data: vec![1.0, 2.0, 3.0, 4.0, 5.0],
            color: "#3b82f6".to_string(),
            line_width: 2.0,
            marker_size: 4.0,
        });

        let svg = chart.render_svg();
        assert!(svg.contains("svg"));
        assert!(svg.contains("Test Chart"));
    }
}
