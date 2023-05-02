module DataSets

include("utils.jl")
include("reader.jl")
include("loader.jl")

export read_ts_file
using ._Reader: read_ts_file

export load_dataset
using ._Loader: list_available_datasets, load_dataset, dataset_flatten_to_matrix

# List of available data set loaders
module Loaders
include("Loaders/UCRArchive.jl")

export UCRArchive
using ._UCRArchiveLoader: UCRArchive

end
export Loaders

end