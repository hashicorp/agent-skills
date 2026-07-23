// Copyright IBM Corp. 2025, 2026
// SPDX-License-Identifier: MPL-2.0

package provider

import (
	"context"
	"os"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/provider/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

var _ provider.Provider = &demoProvider{}

// New returns the provider factory consumed by main.go.
func New(version string) func() provider.Provider {
	return func() provider.Provider {
		return &demoProvider{version: version}
	}
}

// TODO: Rename demoProvider (and the "demo" TypeName below) after your provider.
type demoProvider struct {
	version string
}

type demoProviderModel struct {
	Endpoint types.String `tfsdk:"endpoint"`
	APIKey   types.String `tfsdk:"api_key"`
}

func (p *demoProvider) Metadata(_ context.Context, _ provider.MetadataRequest, resp *provider.MetadataResponse) {
	// TODO: Update this with your provider's type name. It is the prefix of
	// every resource and data source type (e.g. "demo" -> demo_widget).
	resp.TypeName = "demo"
	resp.Version = p.version
}

func (p *demoProvider) Schema(_ context.Context, _ provider.SchemaRequest, resp *provider.SchemaResponse) {
	resp.Schema = schema.Schema{
		Attributes: map[string]schema.Attribute{
			// Authentication attributes are Optional (never Required) so
			// environment variables can supply them; secrets are Sensitive.
			// TODO: Replace endpoint/api_key and the DEMO_* environment
			// variables with your API's connection settings.
			"endpoint": schema.StringAttribute{
				Optional:            true,
				MarkdownDescription: "API endpoint. May also be set via the `DEMO_ENDPOINT` environment variable.",
			},
			"api_key": schema.StringAttribute{
				Optional:            true,
				Sensitive:           true,
				MarkdownDescription: "API key. May also be set via the `DEMO_API_KEY` environment variable.",
			},
		},
	}
}

func (p *demoProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
	var config demoProviderModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}

	// Values wired to other resources' outputs are unknown during planning;
	// treating them as empty would silently mis-authenticate.
	if config.Endpoint.IsUnknown() {
		resp.Diagnostics.AddAttributeError(
			path.Root("endpoint"),
			"Unknown endpoint",
			"endpoint depends on a value known only after apply. Set a static value or use the DEMO_ENDPOINT environment variable.",
		)
	}
	if config.APIKey.IsUnknown() {
		resp.Diagnostics.AddAttributeError(
			path.Root("api_key"),
			"Unknown API key",
			"api_key depends on a value known only after apply. Set a static value or use the DEMO_API_KEY environment variable.",
		)
	}
	if resp.Diagnostics.HasError() {
		return
	}

	// Explicit configuration wins; environment variables are the fallback.
	endpoint := config.Endpoint.ValueString()
	if endpoint == "" {
		endpoint = os.Getenv("DEMO_ENDPOINT")
	}
	apiKey := config.APIKey.ValueString()
	if apiKey == "" {
		apiKey = os.Getenv("DEMO_API_KEY")
	}

	if endpoint == "" {
		resp.Diagnostics.AddAttributeError(
			path.Root("endpoint"),
			"Missing endpoint",
			"Set endpoint in the provider block or export DEMO_ENDPOINT.",
		)
	}
	if apiKey == "" {
		resp.Diagnostics.AddAttributeError(
			path.Root("api_key"),
			"Missing API key",
			"Set api_key in the provider block or export DEMO_API_KEY.",
		)
	}
	if resp.Diagnostics.HasError() {
		return
	}

	// TODO: Construct your API client here and hand it to resources and data
	// sources. They receive it in their Configure methods via ProviderData.
	//
	//   client := demoapi.NewClient(endpoint, apiKey)
	//   resp.ResourceData = client
	//   resp.DataSourceData = client
	_ = endpoint
	_ = apiKey
}

func (p *demoProvider) Resources(_ context.Context) []func() resource.Resource {
	return []func() resource.Resource{
		// TODO: Register resource constructors here, e.g. NewWidgetResource.
	}
}

func (p *demoProvider) DataSources(_ context.Context) []func() datasource.DataSource {
	return []func() datasource.DataSource{
		// TODO: Register data source constructors here.
	}
}
