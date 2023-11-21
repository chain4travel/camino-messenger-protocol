# Camino Messenger Protocol Documentation

---

> 🚧 **ALPHA CODE NOTICE** 🚧:
> ⚠️ This protocol definition is in the alpha phase of development. It is important to note that during this stage, breaking changes may occur without advance notice. Users should proceed with caution.

---

Welcome to the official documentation for Camino Message Types. The protocol suite is meticulously crafted to cater to a broad range of functionalities associated with the digital travel landscape.

The Camino Messenger protocol is created together with Partners from each vertical (flights, hotels, holiday homes, transfers, car rental, cruise,..). The objective is to create a message standard for the Camino Messenger, that is considered simple, efficient, complete, robust and easy to integrate by all partners. And conclusively it will delightfully be implemented and used by partners. As all other Camino Network components, the Camino Messenger Protocol is open source. Free to be used anywhere, but of course targeted to be used with the Camino Messenger.

Please do not hesitate to communicate your observations on this documentation like uncertainties, mistakes or missing explanations, so that we can continuously improve this documentation. Every Camino Network Partner (Validator) can also participate in official Message Type reviews to help improve the message format.

## Index table

- [Camino Messenger Protocol Documentation](#camino-messenger-protocol-documentation)
  - [Message Type Standard](#message-type-standard)
    - [Workflow](#workflow)
    - [Fields](#fields)
    - [Values](#values)
    - [Validations](#validations)
  - [Semantic Versioning:](#semantic-versioning)
  - [Why Protobuf:](#why-protobuf)
  - [Main Message Types](#main-message-types)
  - [Nested Messages](#nested-messages)

## Message Type Standard

In the WhatsApp messenger, you'll find a couple of standardize message types you can exchange with anybody that has the WhatsApp client installed (text, location, audio, video, contact, document,..). The same for the Camino Messenger, all partners need to be able to uniformly use the flight, hotel, car rental, transfer, activities,.. Message Types, no matter to which partner they are connected.
The use of a Messenger client also allows to define the Message Type Standard beyond field names. There can be enhanced message validation, field data and workflow standardization.

### Workflow

A blockchain is product or service agnostic. Conclusively our strategy is to keep the workflow for the Camino Messenger the same for any product or service as well.

Just like any API end-point from the web2 era, you can check the availability of a provider on the Camino network with a Ping Request

Partner configuration can be managed via the Camino Partner Configurator, which will form part of the Camino Application Suite. Two messages have been made available to enable automatic detection of changed partners and fees:

1. Partner Request gives you all active Camino Network Partners that are buying or selling their products and services.
2. The Network Fee Request gives you the cost of a Message to the Camino Network for operating the Camino Messenger and also the cost of specific messages towards specified providers.
   Because this information is stored on the blockchain, the changes since a certain date/time can be requested using a blockheight parameter.

Any product or service that can be traded on the Camino Network requires an onboarding process to understands which routes and airplanes an airline of flight provider offers. Or which hotels an accommodation provider and which activities a an excursion provider offers. For this onboarding and mapping process we have designed:

1. ProductList Request: a Message Type to discover the products or services a provider is offering with some basic information to decide to distribute the product or service or not and to map it to internal codes.
2. ProductDetails Request: download all the information related to the product or service being offered.

All products and services that can be traded on the Camino Network follow a 3 step approach for the booking process:

1. Search: The first step is that a distribution partner submits a Search Request with a search_id to one or more supply partners. They return a Search Response that includes a search_option_id for each option.
2. Check: to verify whether a search option is still available at the same price after dwelling, the Validate Request refers to the search_id and search_option_id to be booked. The Validate Response returns a validation_id, availability status and total price.
3. Book: The submits a Mint Request that refers to the validation_id. After generating the booking in the Inventory System of the supplier and receiving a supplier reference, the messenger client creates a digital asset on the Camino blockchain and returns a digital_asset_id to the messenger client of the distributor. Which then initiates the transfer of funds to the seller and the digital asset to the buyer in one transaction.

![workflow diagram] (workflow.jpg)

After an initial booking is made, a number of events can happen in its lifecycle to full delivery of the service or product:

1. To facilitate the "ghost booking process" and to check whether the distribution system and inventory system of a supplier have a matching booking status, the RetrieveBooking Request has been designed. For the time being it is not enough to rely on the single point of truth in the blockchain, because we want to provide an easy troubleshooting solution for suppliers to discover mismatches between their inventory system and the blockchain, but also for distributors to gain confidence in the consistency of systems. There is a BookingList and a BookingDetails variant.
2. The CancellationRequest is the standard procedure to cancel a product or service. As usual it includes a CancellationCheck Request to verify if cancellation is possible and what the cancellation cost would be.
3. After an initial product, service or package has been sold, an optional extra or service might be added to a product or a service. This is what we refer to as "upselling" in the industry. At the Camino Network we have designed a Message Type that can be sent to each provider that "owns" the booking for a specific product or service, so that any possible "upgrades" or additions can be offered. The AdditionalServices Request requires the distributor or provider reference to identify the booking. In the Response any optional or alternative product or service may be offered.
4. The BookingModification Request allows for an already confirmed booking to be modified to alternative products or additional services or different dates, if they have previously been offered in a Search Request or Upselling Request.

Finally there is an extensive section of error messages so that adequate follow-up can be designed in the workflow for when something goes wrong. But also to make extensive partner performance visible and troubleshooting of under performing flows easily possible.

### Fields

Each field has a unique numeric identifier (field number) and a specific data type, which can range from scalars like integers, floating-point numbers, booleans, and strings, as well as more complex types such as nested messages and enumerations. These fields are defined in a .proto file, which serves as a contract between communicating parties, specifying the structure of the data they exchange.

The field number serves as an identifier in the binary representation of the message, allowing for efficient encoding and decoding. In proto3 all fields are optional, and there are no built-in mechanisms for specifying required values. In proto3, the absence of a field is unset and return the default value. It will not be serialized to the wire. This means that distinguishing between an explicitly set default value and an unset field may require additional considerations in the application logic. Adding new fields in proto3 does not break backward compatibility with existing code. Unknown fields are ignored during deserialization, enabling systems to gracefully handle messages with additional fields.

The Protobuf message definition specifies fields (name/value pairs), one for each piece of data that you want to include in this type of message. Each field has a name and a type. Primitive or Scalar types are most frequently used and there is a corresponding type definition in the [proto 3 language guide](https://protobuf.dev/programming-guides/proto3/). There is also an extensive variation of field definitions known as ["Well-Known Types"](https://protobuf.dev/reference/protobuf/google.protobuf/).

### Values

The values assigned to fields are serialized into a binary format, making it efficient for data transmission and storage. The binary representation is compact, reducing both bandwidth and storage requirements compared to more verbose formats like JSON. Additionally, protobuf values are strongly typed, providing a level of data integrity and reducing the likelihood of errors during serialization and deserialization processes.

### Validations

Proto3 intentionally omits certain features to maintain simplicity and ease of use. Proto3 primarily relies on language-specific validation mechanisms rather than embedding extensive validation rules within the protobuf specification itself.

Adding additional validation logic in our application code or parsers can help ensure the integrity of the data being exchanged and can assist in catching discrepancies between different implementations/systems. We can consider validation rules for data format and constraints, also to prevent malicious or unintentional injection of incorrect or harmful data. Validations can catch errors early in the development process, which can help speed up implementation.

## Semantic Versioning

Feedback and reviews will lead to a fully backward compatible minor version of the Message Type (i.e. from version 1.0.0 to version 1.1.0). Bugfixes and non functional improvements lead to a patch level version in the third number. A major version signifies a substantial new version, API changes or modifications that break backwards compatibility. Only the latest version will be included in the Camino Messenger Client, except for major versions, the latest previous version will remain available for a very limited time to allow all Camino network Partners to upgrade to the new version.

## Why Protobuf

Protobuf's compact binary serialization format results in smaller message sizes compared to human-readable formats like JSON, making it efficient for data transmission and storage in performance-critical applications. This is particularly beneficial in our search messages where network efficiency is a priority and where the data payload is large due to the many products and services offered in search responses. Protobuf offers a better performance than JSON in terms of serialization and deserialization speed where Protobuf's native libraries are used. Protobuf schemas are strongly typed, which leads to more robust code. Protobuf provides built-in support for evolving data structure over time while maintaining backward and forward compatibility. Protobuf is language-agnostic. Nested messages in Protobuf are a powerful feature that allow definition of a message type within another message type. This is akin to declaring a class within another class in object-oriented programming languages. There is an extensive variation of field definitions known as "Well-Known Types". There is a vast amount of documentation and examples in [protobuf documentation](https://protobuf.dev/)

In the gRPC metadata you can specify your messageID, from and to wallet addresses, so that the payload remains untouched and encrypted from P2P. You'll also find latency and processing time stamps of the different hops in the metadata, which gives you transparency and helps with troubleshooting.

The `cmp` directory represents the core of our protocol definitions, under which you will find Main Message Types in "services" and Nested Messages in "types".

## Main Message Types

This subset offers high-level communication utilities and interaction schemas for all products and services that can be traded on the Camino Network.
For each vertical you will find a specific search request and response. The purchase workflow is stateful, meaning that the search results are numbered with search_option_ids that can be checked using the validate request and response. Once validated, a product or service can be booked through the mint request and response with a validation_id.

For most of the products and services there will also be downloadable static data messages in the form of "descriptive info" or policies. These work always with a list functionality with a "last update date/time stamp" and a "get details" function for each item in the list.

See above details in Message Type Standard for more generic details or at the introduction of each Message Type, where we go into more detail of this specific message.

- **ping**: A simple utility message type, essential for health checks and service availability confirmations.
- **partners**: discovery of all partners trading on the Camino Network
- **network_fee**: Contains specifications related to network transaction fees.
- **product_list**: List of products or services available from a provider
- **product_details**: Description of products or services available from a provider
- **accommodation**: Defines the message type for Accommodations like hotels and holiday homes.
- **transport**: Defines the message type for Flights, Rail and Transfer.
- **activity**: for Tickets & Excursions
- **cruise**: Cruise (not started)
- **car_rental**: Rent a car, Rent a Camper
- **insurance**: Insurances (not started)
- **camping**: Camping (not started)
- **package**: Packages, inherent format consisting of the above structures for the services/products included in the package
- **flight_status**: Flight status information
- **entry_destination**: Entry requirements & Destination information

## Nested Messages - Data Types

Delving deeper into the data structures and components, protobuf uses shared structures as nested messages, which we call **"types"**. For example the traveller details in traveller.proto. The transformation to your native logic only requires a one-time development for all main Message Types that will be implemented. Nested messages provide a clear, hierarchical structure, making it easier to understand, review and discuss improvements to the Message standard with the Camino Network Partners. Other benefits of the nested structure of Protobuf are the encapsulation leading to cleaner and easier maintainable code and type safety which helps catching errors early in the integration process.

Some examples:

- **coordinate.proto**: Captures geographical coordinates.
- **currency.proto**: Handles different currency types and associated attributes.
- **date.proto**: A flexible schema for managing date-related data.
- **distance.proto**: Quantifies and categorizes distances, catering to various units and interpretations.
- **filter.proto**: Offers dynamic and static filtering capabilities.
- **geo_location.proto**: A comprehensive protocol that merges various geographical parameters.
- **traveller.proto**: Profiles, preferences, and details of travellers.
- **travel_period.proto**: Specifies the time frame for travel plans, vacations, or any related temporal span.

Whether you are integrating the Camino Message Types into your platform, extending its capabilities, or simply learning more about our approach to digital travel solutions, this documentation aims to be your comprehensive guide. We encourage developers and enthusiasts alike to explore and contribute, ensuring that the Camino Message Types remains at the forefront of innovation.
