# dsImagingClient

## Introduction

The `dsImaging` package is a server-side DataSHIELD extension designed to facilitate the interaction with medical images in various formats within a secure DataSHIELD environment. It provides a comprehensive suite of functions that enable researchers to apply segmentation filters (masks) on images, as well as to utilize analysis models including feature extraction through radiomic feature extraction and 3D convolutional neural networks (3D CNN). This integration ensures that the analysis of medical images, such as CT scans, complies with the DataSHIELD security model, maintaining the privacy and security of the data.

Key features of the `dsImaging` package include:
- **Medical image processing:** Functions to interact with medical images in various formats, including DICOM and NIfTI.
- **Segmentation and analysis:** Tools to apply segmentation filters on images and to use analysis models for feature extraction.
- **Compliance with DataSHIELD security model:** Ensures that all image manipulations and analyses are performed in a way that adheres to the disclosure control measures set by DataSHIELD.
- **Integration with radiomics and computer vision:** Facilitates the application of advanced analysis models on medical images, enhancing the research capabilities within the DataSHIELD environment.

## Structure

The `dsImaging` ecosystem comprises two essential components designed to work in tandem: the server-side package (`dsImaging`) and the client-side package (`dsImagingClient`). Each component plays a pivotal role in the integration of medical imaging within the DataSHIELD environment. For comprehensive details on installation, setup, and usage, please refer to the respective repositories:

- **Server-Side package `dsImaging`**: This component is installed on the DataSHIELD server and is responsible for direct interactions with medical images in various formats. It provides functions for image processing, segmentation, and analysis, ensuring that all operations comply with the DataSHIELD security model. For code, installation instructions, and more, visit [https://github.com/isglobal-brge/dsImaging](https://github.com/isglobal-brge/dsImaging).

- **Client-Side package `dsImagingClient`**: Utilized by researchers and data analysts, this package facilitates the communication with the `dsImaging` package on the server. It sends image processing and analysis requests and receives results, ensuring a user-friendly experience for specifying analysis needs and parameters. For code, installation instructions, and more, visit [https://github.com/isglobal-brge/dsImagingClient](https://github.com/isglobal-brge/dsImagingClient).

## Installation

To install the client-side package `dsImagingClient`, follow the steps below. This guide assumes you have R installed on your system and the necessary permissions to install R packages.

The `dsImagingClient` package can be installed directly from GitHub using the `devtools` package. If you do not have `devtools` installed, you can install it using the following command in R:
```
install.packages("devtools")
```

You can then install the `dsImagingClient` package using the following commands in R:
```
library(devtools)
devtools::install_github('isglobal-brge/dsImagingClient')
```

## Acknowledgements

- The development of dsImaging has been supported by the **[RadGen4COPD](https://github.com/isglobal-brge/RadGen4COPD)**, **[P4COPD](https://www.clinicbarcelona.org/en/projects-and-clinical-assays/detail/p4copd-prediction-prevention-personalized-and-precision-management-of-copd-in-young-adults)**, and **[DATOS-CAT](https://datos-cat.github.io/LandingPage)** projects. These collaborations have not only provided essential financial backing but have also affirmed the project's relevance and application in significant research endeavors.
- This project has received funding from the **[Spanish Ministry of Science and Innovation](https://www.ciencia.gob.es/en/)** and **[State Research Agency](https://www.aei.gob.es/en)** through the **“Centro de Excelencia Severo Ochoa 2019-2023” Program [CEX2018-000806-S]** and **[State Research Agency](https://www.aei.gob.es/en)** and **[Fondo Europeo de Desarrollo Regional, UE](https://ec.europa.eu/regional_policy/funding/erdf_en) (PID2021-122855OB-I00)**, and support from the **[Generalitat de Catalunya](https://web.gencat.cat/en/inici/index.html)** through the **CERCA Program** and **[Ministry of Research and Universities](https://recercaiuniversitats.gencat.cat/en/inici/) (2021 SGR 01563)**.

## Contact

For further information or inquiries, please contact:

- **Juan R González**: juanr.gonzalez@isglobal.org
- **David Sarrat González**: david.sarrat@isglobal.org
- **Xavier Escribà-Montagut**: xavier.escriba@isglobal.org

For more details about **DataSHIELD**, visit [https://www.datashield.org](https://www.datashield.org).

For more information about the **Barcelona Institute for Global Health (ISGlobal)**, visit [https://www.isglobal.org](https://www.isglobal.org).