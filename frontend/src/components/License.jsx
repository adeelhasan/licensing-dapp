const moment = require("moment");

export default function LicenseItem({ license, isOwner, buyLicense }) {
    function hex2a(hexx) {
        var hex = hexx.toString();//force conversion
        var str = '';
        for (var i = 0; i < hex.length; i += 2)
            if (parseInt(hex.substr(i, 2), 16))
                str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        return str;
    }
    return (
        <div className="col-span-12 box-border border-0 border-solid border-neutral-200 text-sm leading-5 duration-300 sm:col-span-6 lg:col-span-3">
            <div className="h-full overflow-hidden rounded-lg border-2 border-gray-200 border-opacity-60">
                <div className="p-6">
                    <h1 className="title-font mb-3 text-lg font-medium text-gray-900">
                        {hex2a(license.name)}
                    </h1>
                    <h2 className="title-font mb-1 text-xs font-medium tracking-widest text-gray-900">
                        Cycle length
                    </h2>
                    <p
                        className="mb-3 leading-relaxed"
                        style={{
                            maxWidth: "60%",
                            wordBreak: "break-word",
                        }}
                    >
                        {moment.duration(license.cycleLength).humanize()}
                    </p>
                    <h2 className="title-font mb-1 text-xs font-medium tracking-widest text-gray-900">
                        Price
                    </h2>
                    <p
                        className="mb-3 leading-relaxed"
                        style={{
                            maxWidth: "60%",
                            wordBreak: "break-word",
                        }}
                    >
                        {license.price.toString() + " Wei"}
                    </p>
                    {!isOwner && (
                        <button
                            onClick={()=>buyLicense()}
                            className="flex rounded border-0 bg-indigo-500 py-2 px-8 text-lg text-white hover:bg-indigo-600 focus:outline-none disabled:opacity-50"
                        >
                            BUY
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
